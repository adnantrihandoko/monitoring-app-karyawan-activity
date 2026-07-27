import type { Plugin } from "@opencode-ai/plugin"

export default (async ({ client, project, directory, $ }) => {
  const metrics = {
    tasksCompleted: 0,
    tasksInProgress: 0,
    deployments: 0,
  }

  return {
    config: (cfg) => {},

    "tool.execute.after": async (input, output) => {
      if (input.tool === "bash") {
        const command = input.args.command || ""
        if (command.includes("git commit")) {
          metrics.tasksCompleted++
          console.log(`[Progress] Tasks completed: ${metrics.tasksCompleted}`)
        }
        if (command.includes("deploy") || command.includes("push")) {
          metrics.deployments++
          console.log(`[Progress] Deployments: ${metrics.deployments}`)
        }
      }
    },
  }
}) satisfies Plugin
