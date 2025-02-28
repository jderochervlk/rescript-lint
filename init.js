#! /usr/bin/env node

import { Console } from 'node:console'
import { copyFile, mkdir, readFile, writeFile } from 'node:fs/promises'
import path from 'node:path'
import { abort } from 'node:process'
import { parse, stringify } from 'yaml'

const RULES_DIR = path.resolve(import.meta.dirname, './rules')
const RULES_SRC_DIR = path.resolve(import.meta.dirname, './rules-src')
const CONFIG_FILE = path.resolve(import.meta.dirname, '../rescript-lint.mjs')

const LINT_COMMAND = "sg scan -c node_modules/rescript-lint/sgconfig.yml"

try {
    await mkdir(RULES_DIR)
} catch (_e) { }

try {
    await import(CONFIG_FILE)
} catch {
    console.error("rescript-lint.mjs file not found!")
    process.exit(1)
}

const { rules, include } = (await import(CONFIG_FILE)).default

for (const [rule, setting] of Object.entries(rules)) {
    const ruleFileName = `${rule}.yaml`

    const ruleSourceFile = path.resolve(RULES_SRC_DIR, ruleFileName)
    const ruleTargetFile = path.resolve(RULES_DIR, ruleFileName)

    await copyFile(ruleSourceFile, ruleTargetFile)

    const ruleFile = await readFile(ruleTargetFile, 'utf8')

    const ruleConfig = parse(ruleFile)

    ruleConfig.severity = setting

    const updatedConfig = stringify(ruleConfig)

    await writeFile(ruleTargetFile, updatedConfig)
}

const VSCODE_SETTINGS_PATH = path.resolve(import.meta.dirname, '../.vscode/settings.json')

try {
    const vscodeSettings = (await import(VSCODE_SETTINGS_PATH, { with: { "type": "json" } })).default

    console.log(vscodeSettings)

    if (!vscodeSettings["astGrep.configPath"]) {
        writeFile(VSCODE_SETTINGS_PATH, JSON.stringify({
            ...vscodeSettings,
            "astGrep.configPath": "node_modules/rescript-lint/sgconfig.yml"
        }, null, 2
        ))
    }
} catch (_) {
    try {
        await mkdir(path.resolve(import.meta.dirname, '../.vscode'))
    } catch (_) {

    }
    writeFile(VSCODE_SETTINGS_PATH, JSON.stringify({
        "astGrep.configPath": "node_modules/rescript-lint/sgconfig.yml"
    }, null, 2
    ))
}

await writeFile('lint.sh', `${LINT_COMMAND} ${include || 'src'}`)

console.log("Successfully configured rescript-ast-grep!")
console.log("Restart the ast-grep language server or restat VSCode to pick up the latest config.")