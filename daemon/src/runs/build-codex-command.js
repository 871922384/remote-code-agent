function buildCodexCommand({ codexBin, prompt }) {
  return {
    command: codexBin,
    args: ['exec', '--skip-git-repo-check', '--json', prompt],
  };
}

module.exports = {
  buildCodexCommand,
};
