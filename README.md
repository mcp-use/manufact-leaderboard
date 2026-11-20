# Manufact Leaderboard

Rescan your MCP server on the [Manufact leaderboard](https://manufact.com/leaderboard) after every deploy, wait for the review, and get the new score in the run summary.

The server must be verified by your workspace first: open its leaderboard page and choose **Verify**. Only the verifying workspace can rescan it.

## Usage

Add a `MANUFACT_API_KEY` repository secret with an API key from that workspace, then add a step after your deploy:

```yaml
- name: Manufact Leaderboard
  uses: mcp-use/manufact-leaderboard@v1
  with:
    api-key: ${{ secrets.MANUFACT_API_KEY }}
    url: https://mcp.example.com/mcp
```

The step prints the score and a report link, and writes them to the job summary. A rescan that can't start, fails, or runs past the timeout leaves a warning and never fails your deploy, unless you set `fail-on-error: true`.

## Inputs

| Input | Default | Description |
| --- | --- | --- |
| `api-key` | required | Manufact API key from the workspace that verified the server. |
| `url` | required | The server's MCP endpoint URL, as listed on the leaderboard. |
| `wait` | `true` | Wait for the rescan and report the score. `false` only starts it. |
| `timeout-minutes` | `10` | How long to wait for the rescan. |
| `fail-on-error` | `false` | Fail the step when the rescan can't start or fails. |
| `api-url` | `https://api.manufact.com` | Manufact API base URL. |
| `site-url` | `https://manufact.com` | Manufact website base URL, for the report link. |

## Outputs

| Output | Description |
| --- | --- |
| `score` | Score out of 100 after the rescan. |
| `status` | `completed`, `failed`, `running` (timed out) or `started` (`wait: false`). |
| `slug` | The server's leaderboard slug. |
| `report-url` | Link to the server's leaderboard report. |

Use the score in a later step, for example to comment on a pull request:

```yaml
- id: leaderboard
  uses: mcp-use/manufact-leaderboard@v1
  with:
    api-key: ${{ secrets.MANUFACT_API_KEY }}
    url: https://mcp.example.com/mcp
- run: echo "Score ${{ steps.leaderboard.outputs.score }} - ${{ steps.leaderboard.outputs.report-url }}"
```

The action uses `bash`, `curl` and `jq`, which GitHub-hosted runners include.
