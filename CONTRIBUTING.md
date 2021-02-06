TODO: Write about contributing to ABIN source code,
- installing dev dependencies vi dev_scripts/setup_dev_environment.sh
- code style and fprettify

### Optional dependencies

### Inspecting Git history

To ignore bulk whitespace changes in blame history, use:
```sh
git blame --ignore-revs-file .git-blame-ignore-revs
```

or to do it automatically:
```sh
git config blame.ignoreRevsFile .git-blame-ignore-revs

Unfortunately, this is not yet supported in
[the GitHub UI](https://github.community/t/support-ignore-revs-file-in-githubs-blame-view/3256),
but Github UI already allows to browse git blame a bit.
