# Release Process

This document describes how to publish Helm chart releases.

## Creating a Release

### 1. Prepare the Release

Update the relevant chart version in `Chart.yaml`, merge the change to `main`, and make sure the chart is ready to publish.

### 2. Create and Push a Version Tag

Check out the commit on `main` that contains the version bump, then create an annotated tag that matches the chart name and chart version. The workflow packages the chart from the tagged commit, not from the current tip of `main`.

```bash
git tag -a kubernetes-agent-2.9.6 -m "Release kubernetes-agent-2.9.6"
git push origin kubernetes-agent-2.9.6
```

For the broker client chart:

```bash
git tag -a broker-client-1.0.22 -m "Release broker-client-1.0.22"
git push origin broker-client-1.0.22
```

The release workflow validates that the tag matches `Chart.yaml` before publishing.

### 3. Monitor the Release

Go to the Actions tab in GitHub and watch the "Release & Publish" workflow. The workflow creates the GitHub release, uploads the packaged chart, and updates the Helm repository index.

If the workflow fails for a transient reason, re-run the failed run from the Actions tab. Re-runs use the tagged commit, so if the chart or workflow needs a fix, merge it to `main`, bump the chart version and push a new tag. Release tags are protected, so do not delete or move them.
