import type { Plugin } from "@opencode-ai/plugin"

export default (async ({ client, project, directory, $ }) => {
  const securityPatterns = [
    /password\s*[:=]\s*["']/i,
    /api[_-]?key\s*[:=]\s*["']/i,
    /secret\s*[:=]\s*["']/i,
  ]

  return {
    "tool.execute.after": async (input, output) => {
      if (input.tool === "edit" || input.tool === "write") {
        const content = output.result || ""
        for (const pattern of securityPatterns) {
          if (pattern.test(content)) {
            console.log("[Security] Potential secret detected!")
            console.log("[Security] Use environment variables instead.")
          }
        }
      }
    },
  }
}) satisfies Plugin
