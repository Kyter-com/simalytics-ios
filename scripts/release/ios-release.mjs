#!/usr/bin/env node

import { existsSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import config from "./config.mjs";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(scriptDir, "../..");
const ascBin = process.env.ASC_BIN || "/opt/homebrew/bin/asc";
const command = process.argv[2] || "help";
const args = process.argv.slice(3);
let resolvedAppRef;
let ascCredentialTempDir;
let ascCredentialEnv;
const preReleaseVersionCache = new Map();

function run(bin, commandArgs, options = {}) {
  const result = spawnSync(bin, commandArgs, {
    cwd: rootDir,
    encoding: "utf8",
    input: options.input,
    env: options.env || process.env,
  });

  if (result.error) {
    if (options.allowFailure) return result;
    throw result.error;
  }

  if (result.status !== 0 && !options.allowFailure) {
    const detail = result.stderr.trim() || result.stdout.trim() || `exit ${result.status}`;
    throw new Error(`${bin} ${commandArgs.join(" ")} failed: ${detail}`);
  }

  return result;
}

function cleanupAscCredentials() {
  if (!ascCredentialTempDir) return;
  rmSync(ascCredentialTempDir, { recursive: true, force: true });
  ascCredentialTempDir = undefined;
}

process.on("exit", cleanupAscCredentials);

function ascEnv() {
  if (process.env.ASC_PRIVATE_KEY_PATH || !process.env.ASC_OP_ITEM) return process.env;
  if (ascCredentialEnv) return ascCredentialEnv;

  const vault = process.env.ASC_OP_VAULT;
  const account = process.env.ASC_OP_ACCOUNT;
  const item = process.env.ASC_OP_ITEM;
  const keyId = opField(item, "key_id", vault, account);
  const issuerId = opField(item, "issuer_id", vault, account);
  const privateKey = opField(item, "credential", vault, account);

  ascCredentialTempDir = mkdtempSync(path.join(os.tmpdir(), "asc-key-"));
  const keyPath = path.join(ascCredentialTempDir, "AuthKey.p8");
  writeFileSync(keyPath, privateKey, { mode: 0o600 });

  ascCredentialEnv = {
    ...process.env,
    ASC_KEY_ID: keyId,
    ASC_ISSUER_ID: issuerId,
    ASC_PRIVATE_KEY_PATH: keyPath,
    ASC_BYPASS_KEYCHAIN: process.env.ASC_BYPASS_KEYCHAIN || "1",
  };
  return ascCredentialEnv;
}

function opField(item, label, vault, account) {
  const commandArgs = [
    "item",
    "get",
    item,
    "--fields",
    `label=${label}`,
    "--reveal",
    "--format",
    "json",
  ];
  if (account) commandArgs.splice(3, 0, "--account", account);
  if (vault) commandArgs.splice(account ? 5 : 3, 0, "--vault", vault);

  const result = run("op", commandArgs);
  const payload = parseJson(result.stdout);
  const field = Array.isArray(payload) ? payload[0] : payload;
  const value = field?.value;

  if (!value) throw new Error(`Could not read ${label} from 1Password item ${item}.`);
  return value;
}

function hasFlag(flag) {
  return args.includes(flag);
}

function flagValue(flag, fallback = undefined) {
  const index = args.indexOf(flag);
  return index === -1 ? fallback : args[index + 1];
}

function readJson(relativePath) {
  return JSON.parse(readFileSync(path.join(rootDir, relativePath), "utf8"));
}

function readXcodeSettings() {
  const projectPath = path.join(rootDir, config.xcodeProject);
  const content = readFileSync(projectPath, "utf8");
  const marketingVersion = firstMatch(content, /\bMARKETING_VERSION = ([^;]+);/g);
  const buildNumber = firstMatch(content, /\bCURRENT_PROJECT_VERSION = ([^;]+);/g);
  const bundleId = firstMatch(content, /\bPRODUCT_BUNDLE_IDENTIFIER = ([^;]+);/g);

  return { marketingVersion, buildNumber, bundleId };
}

function firstMatch(content, expression) {
  const match = expression.exec(content);
  return match ? match[1].replaceAll('"', "").trim() : undefined;
}

function replaceXcodeSetting(setting, value) {
  const projectPath = path.join(rootDir, config.xcodeProject);
  const content = readFileSync(projectPath, "utf8");
  const expression = new RegExp(`\\b${setting} = [^;]+;`, "g");

  if (!content.match(expression)) {
    throw new Error(`No ${setting} entries were found in ${config.xcodeProject}.`);
  }

  const nextContent = content.replace(expression, `${setting} = ${value};`);

  writeFileSync(projectPath, nextContent);
}

function syncXcodeVersion() {
  const pkg = readJson("package.json");
  replaceXcodeSetting("MARKETING_VERSION", pkg.version);
  console.log(`${config.xcodeProject} MARKETING_VERSION is ${pkg.version}.`);
}

function changesetFiles() {
  const changesetDir = path.join(rootDir, ".changeset");
  if (!existsSync(changesetDir)) return [];

  return readdirSync(changesetDir)
    .filter((file) => file.endsWith(".md") && file !== "README.md")
    .map((file) => path.join(changesetDir, file));
}

function changesetNotes() {
  return changesetFiles().flatMap((file) => {
    const content = readFileSync(file, "utf8");
    if (!content.includes(`"${config.packageName}"`)) return [];

    const body = content.replace(/^---[\s\S]*?---\s*/m, "").trim();
    return noteBodyToItems(body);
  });
}

function noteBodyToItems(body) {
  if (!body) return [];

  const items = [];
  let paragraph = [];

  for (const rawLine of body.split("\n")) {
    const line = rawLine.trim();

    if (!line) {
      flushParagraph();
      continue;
    }

    const bullet = line.match(/^(?:[-*•]\s+)(.+)$/u);
    if (bullet) {
      flushParagraph();
      items.push(cleanNote(bullet[1]));
      continue;
    }

    if (!line.startsWith("#")) paragraph.push(line);
  }

  flushParagraph();
  return items.filter(Boolean);

  function flushParagraph() {
    if (paragraph.length === 0) return;
    items.push(cleanNote(paragraph.join(" ")));
    paragraph = [];
  }
}

function cleanNote(note) {
  return note.replace(/^[-*•]\s+/u, "").replace(/\s+/g, " ").trim();
}

function latestReleaseTag() {
  const result = run(
    "git",
    ["describe", "--tags", "--match", `${config.gitTagPrefix}*`, "--abbrev=0"],
    { allowFailure: true }
  );

  return result.status === 0 ? result.stdout.trim() : undefined;
}

function gitNotes() {
  const tag = flagValue("--since-tag", latestReleaseTag());
  const range = tag ? `${tag}..HEAD` : "HEAD";
  const result = run("git", ["log", "--reverse", "--format=%s", range], { allowFailure: true });
  if (result.status !== 0) return [];

  return result.stdout
    .split("\n")
    .map((line) => formatCommitSubject(line.trim()))
    .filter(Boolean);
}

function formatCommitSubject(subject) {
  if (!subject) return undefined;
  if (/^(chore|ci|docs|test)(\(.+\))?:/i.test(subject)) return undefined;
  if (/\b(version|build number|release train|app store metadata)\b/i.test(subject)) return undefined;
  if (/^Merge pull request/i.test(subject)) return undefined;

  return subject
    .replace(/^(feat|fix|perf|refactor|style)(\(.+\))?:\s*/i, "")
    .replace(/^[a-z]/, (letter) => letter.toUpperCase());
}

function formatNotes(notes) {
  const uniqueNotes = [...new Set(notes.map(cleanNote).filter(Boolean))];
  return uniqueNotes.map((note) => `• ${note}`).join("\n");
}

function generatedNotes() {
  const pendingChangesets = changesetNotes();
  if (!hasFlag("--from-git")) return pendingChangesets;

  const fromGit = gitNotes();
  if (fromGit.length > 0) return fromGit;

  return pendingChangesets;
}

function printNotes() {
  const notes = formatNotes(generatedNotes());
  const outputPath = flagValue("--write", hasFlag("--write-default") ? config.nextReleaseNotesPath : undefined);

  if (!notes) {
    if (hasFlag("--allow-empty")) {
      console.log("No release notes found; continuing because --allow-empty was provided.");
      return;
    }

    console.error("No release notes found. Add a changeset with `npm run changeset`, or pass --from-git for an audit draft.");
    process.exitCode = 1;
    return;
  }

  if (notes.length > 4000) {
    console.error(`Warning: notes are ${notes.length} characters; App Store Connect allows up to 4000.`);
  }

  if (outputPath) {
    writeFileSync(path.join(rootDir, outputPath), `${notes}\n`);
    console.log(`Wrote ${outputPath}.`);
  } else {
    console.log(notes);
  }
}

function status() {
  const pkg = readJson("package.json");
  const xcode = readXcodeSettings();

  console.log(`${config.appName}`);
  console.log(`Package version: ${pkg.version}`);
  console.log(`Xcode marketing version: ${xcode.marketingVersion}`);
  console.log(`Xcode build number: ${xcode.buildNumber}`);
  console.log(`Bundle ID: ${config.bundleId}`);
  console.log("");

  const asc = run(
    ascBin,
    ["status", "--app", config.bundleId, "--platform", config.platform, "--include", "app,builds,testflight,appstore,submission", "--output", "table"],
    { allowFailure: true, env: ascEnv() }
  );

  if (asc.status === 0) {
    console.log(asc.stdout.trim());
    return;
  }

  console.log("ASC status unavailable.");
  console.log("Run through an authenticated 1Password/ASC environment, for example:");
  console.log("op run --env-file <private-asc-env> -- npm run release:status");
}

function nextBuild() {
  const xcode = readXcodeSettings();
  const version = flagValue("--version", xcode.marketingVersion);
  const app = resolveAppRef();
  const result = run(ascBin, [
    "builds",
    "next-build-number",
    "--app",
    app,
    "--version",
    version,
    "--platform",
    config.platform,
    "--output",
    "json",
    "--pretty",
  ], { env: ascEnv() });

  const payload = parseJson(result.stdout);
  const buildNumber = findValue(payload, ["nextBuildNumber", "buildNumber", "next"]);

  if (!buildNumber) {
    console.log(result.stdout.trim());
    throw new Error("Could not find the next build number in asc output.");
  }

  console.log(`Next ${config.appName} ${version} build number: ${buildNumber}`);

  if (hasFlag("--apply")) {
    replaceXcodeSetting("CURRENT_PROJECT_VERSION", String(buildNumber));
    console.log(`Synced ${config.xcodeProject} CURRENT_PROJECT_VERSION to ${buildNumber}.`);
  }
}

function applyNotes() {
  const target = flagValue("--target", "both");
  const confirmed = hasFlag("--confirm");
  const xcode = readXcodeSettings();
  const notes = notesFromFileOrChangesets();
  const app = confirmed ? resolveAppRef() : config.bundleId;

  if (!notes) throw new Error("No notes were found to apply.");

  const planned = [];
  if (target === "both" || target === "appstore") planned.push("appstore");
  if (target === "both" || target === "testflight") planned.push("testflight");
  if (planned.length === 0) throw new Error("Use --target appstore, --target testflight, or --target both.");

  if (!confirmed) {
    console.log("Dry run. Re-run with --confirm to update App Store Connect.");
    console.log(`Version: ${xcode.marketingVersion}`);
    console.log(`Build: ${xcode.buildNumber}`);
    console.log(`Targets: ${planned.join(", ")}`);
    console.log("");
    console.log(notes);
    return;
  }

  if (planned.includes("appstore")) {
    run(ascBin, [
      "apps",
      "info",
      "edit",
      "--app",
      app,
      "--version",
      xcode.marketingVersion,
      "--platform",
      config.platform,
      "--locale",
      config.locale,
      "--whats-new",
      notes,
    ], { env: ascEnv() });
    console.log("Updated App Store What's New notes.");
  }

  if (planned.includes("testflight")) {
    const update = run(
      ascBin,
      [
        "builds",
        "test-notes",
        "update",
        "--app",
        app,
        "--build-number",
        xcode.buildNumber,
        "--version",
        xcode.marketingVersion,
        "--platform",
        config.platform,
        "--locale",
        config.locale,
        "--whats-new",
        notes,
      ],
      { allowFailure: true, env: ascEnv() }
    );

    if (update.status !== 0) {
      run(ascBin, [
        "builds",
        "test-notes",
        "create",
        "--app",
        app,
        "--build-number",
        xcode.buildNumber,
        "--version",
        xcode.marketingVersion,
        "--platform",
        config.platform,
        "--locale",
        config.locale,
        "--whats-new",
        notes,
      ], { env: ascEnv() });
    }

    console.log("Updated TestFlight What to Test notes.");
  }
}

function notesFromFileOrChangesets() {
  const notesFile = flagValue("--notes-file");
  if (notesFile) return readFileSync(path.join(rootDir, notesFile), "utf8").trim();

  const pendingNotes = formatNotes(changesetNotes());
  if (pendingNotes) return pendingNotes;

  const savedNotesPath = path.join(rootDir, config.nextReleaseNotesPath);
  if (existsSync(savedNotesPath)) return readFileSync(savedNotesPath, "utf8").trim();

  return "";
}

function backfill() {
  const app = resolveAppRef();
  const versionsPayload = ascJson(["versions", "list", "--app", app, "--platform", config.platform, "--paginate", "--output", "json", "--pretty"]);
  const buildsPayload = ascJson(["builds", "list", "--app", app, "--platform", config.platform, "--processing-state", "all", "--paginate", "--output", "json", "--pretty"]);
  const versions = asArray(versionsPayload).map(normalizeVersion).filter((version) => version.version);
  const builds = asArray(buildsPayload).map(normalizeBuild).filter((build) => build.buildNumber || build.version);
  const snapshots = gitVersionSnapshots();

  const versionNotes = new Map();
  for (const version of versions) {
    const notes = fetchWhatsNew(version.version);
    if (notes) versionNotes.set(version.version, notes);
  }

  const lines = [];
  lines.push("# Apple Release History");
  lines.push("");
  lines.push(`Generated from App Store Connect and git on ${new Date().toISOString()}.`);
  lines.push("");
  lines.push("ASC is the source of truth for Apple versions and builds. Git commits are correlated by Xcode `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` snapshots.");
  lines.push("");
  lines.push("## App Store Versions");
  lines.push("");
  lines.push("| Version | State | Created | Released | Matched Git Commit | What's New |");
  lines.push("| --- | --- | --- | --- | --- | --- |");

  for (const version of sortVersions(versions)) {
    const matched = findSnapshot(snapshots, version.version);
    lines.push(`| ${version.version} | ${version.state || ""} | ${version.createdDate || ""} | ${version.releaseDate || ""} | ${formatSnapshot(matched)} | ${singleLine(versionNotes.get(version.version))} |`);
  }

  lines.push("");
  lines.push("## Builds");
  lines.push("");
  lines.push("| Version | Build | Uploaded | Processing State | Expired | Matched Git Commit |");
  lines.push("| --- | --- | --- | --- | --- | --- |");

  const sortedBuilds = sortBuilds(builds);
  for (const build of sortedBuilds) {
    const matched = findSnapshot(snapshots, build.version, build.buildNumber);
    lines.push(`| ${build.version || ""} | ${build.buildNumber || ""} | ${build.uploadedDate || ""} | ${build.processingState || ""} | ${build.expired ?? ""} | ${formatSnapshot(matched)} |`);
  }

  lines.push("");
  lines.push("## Correlated Commits");

  let previousCommit;
  for (const build of sortedBuilds) {
    const matched = findSnapshot(snapshots, build.version, build.buildNumber);
    if (!matched) continue;

    lines.push("");
    lines.push(`### ${build.version || matched.marketingVersion} (${build.buildNumber || matched.buildNumber})`);
    lines.push("");
    lines.push(`Matched ${matched.shortSha} from ${matched.date}: ${matched.subject}`);
    lines.push("");

    const commits = commitsBetween(previousCommit, matched.sha);
    if (commits.length === 0) {
      lines.push("No commits found in this range.");
    } else {
      for (const commit of commits) lines.push(`- ${commit}`);
    }

    previousCommit = matched.sha;
  }

  lines.push("");
  writeFileSync(path.join(rootDir, config.releaseHistoryPath), `${lines.join("\n")}\n`);
  console.log(`Wrote ${config.releaseHistoryPath}.`);
}

function ascJson(commandArgs) {
  const result = run(ascBin, commandArgs, { env: ascEnv() });
  return parseJson(result.stdout);
}

function resolveAppRef() {
  if (config.appId) return config.appId;
  if (resolvedAppRef) return resolvedAppRef;

  const payload = ascJson(["apps", "list", "--bundle-id", config.bundleId, "--limit", "1", "--output", "json", "--pretty"]);
  const app = asArray(payload)[0];
  const id = app?.id || attr(app, "id") || findValue(app, ["id", "appId"]);

  if (!id) {
    throw new Error(`Could not resolve an App Store Connect app ID for ${config.bundleId}.`);
  }

  resolvedAppRef = String(id);
  return resolvedAppRef;
}

function parseJson(value) {
  try {
    return JSON.parse(value);
  } catch (error) {
    throw new Error(`Could not parse JSON output: ${error.message}\n${value}`);
  }
}

function asArray(payload) {
  if (Array.isArray(payload)) return payload;
  if (Array.isArray(payload.data)) return payload.data;
  if (Array.isArray(payload.items)) return payload.items;
  if (Array.isArray(payload.results)) return payload.results;
  if (payload.data && Array.isArray(payload.data.data)) return payload.data.data;
  return [];
}

function normalizeVersion(item) {
  return {
    version: attr(item, "versionString") || attr(item, "version"),
    state: attr(item, "appStoreState") || attr(item, "state"),
    createdDate: dateOnly(attr(item, "createdDate") || attr(item, "createdAt")),
    releaseDate: dateOnly(attr(item, "releaseDate") || attr(item, "releasedDate")),
  };
}

function normalizeBuild(item) {
  return {
    id: item?.id,
    version: findBuildMarketingVersion(item),
    buildNumber: findValue(item, ["buildNumber", "version"]),
    uploadedDate: dateOnly(findValue(item, ["uploadedDate", "uploadedAt", "createdDate"])),
    processingState: findValue(item, ["processingState"]),
    expired: findValue(item, ["expired"]),
  };
}

function findBuildMarketingVersion(item) {
  const version = findValue(item, ["marketingVersion", "versionString", "preReleaseVersionString"]);
  if (version) return version;

  const preReleaseVersionId = item?.relationships?.preReleaseVersion?.data?.id;
  if (!preReleaseVersionId && !item?.id) return undefined;

  return preReleaseVersion(preReleaseVersionId, item.id);
}

function preReleaseVersion(preReleaseVersionId, buildId) {
  const cacheKey = preReleaseVersionId || buildId;
  if (preReleaseVersionCache.has(cacheKey)) return preReleaseVersionCache.get(cacheKey);

  const result = run(
    ascBin,
    ["builds", "pre-release-version", "view", "--build-id", buildId, "--output", "json", "--pretty"],
    { allowFailure: true, env: ascEnv() }
  );
  if (result.status !== 0) return undefined;

  const payload = parseJson(result.stdout);
  const version = findValue(payload, ["version"]);
  preReleaseVersionCache.set(cacheKey, version);
  return version;
}

function attr(item, key) {
  return item?.attributes?.[key] ?? item?.[key];
}

function findValue(value, keys) {
  if (!value || typeof value !== "object") return undefined;

  for (const key of keys) {
    if (value[key] !== undefined && value[key] !== null) return value[key];
    if (value.attributes?.[key] !== undefined && value.attributes?.[key] !== null) return value.attributes[key];
  }

  for (const nested of Object.values(value)) {
    if (!nested || typeof nested !== "object") continue;
    const found = findValue(nested, keys);
    if (found !== undefined && found !== null) return found;
  }

  return undefined;
}

function fetchWhatsNew(version) {
  const app = resolveAppRef();
  const result = run(
    ascBin,
    ["apps", "info", "view", "--app", app, "--version", version, "--platform", config.platform, "--locale", config.locale, "--output", "json", "--pretty"],
    { allowFailure: true, env: ascEnv() }
  );

  if (result.status !== 0) return undefined;

  const payload = parseJson(result.stdout);
  return findValue(payload, ["whatsNew", "whats_new"]);
}

function gitVersionSnapshots() {
  const log = run("git", ["log", "--reverse", "--format=%H%x09%ad%x09%s", "--date=short", "--", config.xcodeProject]).stdout.trim();
  if (!log) return [];

  const snapshots = [];
  let previous;

  for (const line of log.split("\n")) {
    const [sha, date, ...subjectParts] = line.split("\t");
    const subject = subjectParts.join("\t");
    const show = run("git", ["show", `${sha}:${config.xcodeProject}`], { allowFailure: true });
    if (show.status !== 0) continue;

    const marketingVersion = firstMatch(show.stdout, /\bMARKETING_VERSION = ([^;]+);/g);
    const buildNumber = firstMatch(show.stdout, /\bCURRENT_PROJECT_VERSION = ([^;]+);/g);
    const changed = !previous || previous.marketingVersion !== marketingVersion || previous.buildNumber !== buildNumber;

    if (changed || /\b(version|build|release)\b/i.test(subject)) {
      snapshots.push({
        sha,
        shortSha: sha.slice(0, 7),
        date,
        subject,
        marketingVersion,
        buildNumber,
      });
    }

    previous = { marketingVersion, buildNumber };
  }

  return snapshots;
}

function findSnapshot(snapshots, version, buildNumber) {
  const exact = snapshots.find((snapshot) => snapshot.marketingVersion === version && String(snapshot.buildNumber) === String(buildNumber));
  if (exact) return exact;

  const versionOnly = [...snapshots].reverse().find((snapshot) => snapshot.marketingVersion === version);
  return versionOnly;
}

function commitsBetween(previousSha, sha) {
  const range = previousSha ? `${previousSha}..${sha}` : sha;
  const result = run("git", ["log", "--reverse", "--format=%s", range], { allowFailure: true });
  if (result.status !== 0) return [];

  return result.stdout
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);
}

function sortVersions(versions) {
  return [...versions].sort((left, right) => compareNullable(left.createdDate || left.version, right.createdDate || right.version));
}

function sortBuilds(builds) {
  return [...builds].sort((left, right) => {
    const dateComparison = compareNullable(left.uploadedDate, right.uploadedDate);
    if (dateComparison !== 0) return dateComparison;
    return Number(left.buildNumber || 0) - Number(right.buildNumber || 0);
  });
}

function compareNullable(left, right) {
  if (!left && !right) return 0;
  if (!left) return 1;
  if (!right) return -1;
  return String(left).localeCompare(String(right));
}

function dateOnly(value) {
  return typeof value === "string" ? value.slice(0, 10) : value;
}

function singleLine(value) {
  return value ? String(value).replace(/\s+/g, " ").replaceAll("|", "\\|").trim() : "";
}

function formatSnapshot(snapshot) {
  return snapshot ? `${snapshot.shortSha} (${snapshot.date})` : "";
}

function tagRelease() {
  const xcode = readXcodeSettings();
  const tag = flagValue("--tag", `${config.gitTagPrefix}${xcode.marketingVersion}+${xcode.buildNumber}`);

  if (!hasFlag("--confirm")) {
    console.log(`Dry run. Re-run with --confirm to create tag ${tag}.`);
    return;
  }

  const dirty = run("git", ["status", "--short"]).stdout.trim();

  if (dirty && !hasFlag("--allow-dirty")) {
    throw new Error("Working tree is dirty. Commit release files first, or pass --allow-dirty intentionally.");
  }

  const existing = run("git", ["rev-parse", "--verify", `refs/tags/${tag}`], { allowFailure: true });
  if (existing.status === 0) {
    console.log(`Tag ${tag} already exists.`);
    return;
  }

  run("git", ["tag", "-a", tag, "-m", `${config.appName} ${xcode.marketingVersion} (${xcode.buildNumber})`]);
  console.log(`Created tag ${tag}.`);
}

function printHelp() {
  console.log(`Usage: node scripts/release/ios-release.mjs <command> [options]

Commands:
  notes                         Print App Store-style notes from pending changesets.
  notes --from-git              Print notes from git commits since the latest release tag.
  notes --write-default         Write notes to ${config.nextReleaseNotesPath}.
  status                        Show local version/build and ASC release status.
  next-build [--apply]          Ask ASC for the next build number and optionally update Xcode.
  sync-xcode-version            Sync Xcode MARKETING_VERSION from package.json.
  apply-notes [--confirm]       Apply generated notes to ASC metadata/TestFlight.
  backfill                      Pull ASC versions/builds and correlate them with git commits.
  tag [--confirm]               Create a git release tag using ${config.gitTagPrefix}<version>+<build>.
`);
}

try {
  switch (command) {
    case "notes":
      printNotes();
      break;
    case "status":
      status();
      break;
    case "next-build":
      nextBuild();
      break;
    case "sync-xcode-version":
      syncXcodeVersion();
      break;
    case "apply-notes":
      applyNotes();
      break;
    case "backfill":
      backfill();
      break;
    case "tag":
      tagRelease();
      break;
    default:
      printHelp();
  }
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
