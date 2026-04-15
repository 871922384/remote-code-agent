function buildCodexCommand({ codexBin, prompt }) {
  return {
    command: codexBin,
    args: ['exec', '--skip-git-repo-check', prompt],
  };
}

module.exports = {
  buildCodexCommand,
};
