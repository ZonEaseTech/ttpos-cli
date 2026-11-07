#!/bin/sh
# 把给定目录的包发布到 npm（入口包要放到最后单独调用，它一发 latest 就指向新版本）。
# 可重入：registry 上已有的版本核对内容后跳过；内容和本次构建不一致就失败，防止同一
# 版本号混发新旧二进制（此时应升版本号）。认证由 npm 可信发布（OIDC）提供。
set -eu
VERSION=${1:?"用法: publish.sh <version> <包目录>..."}; shift
for dir in "$@"; do
  name=$(node -p "require('./$dir/package.json').name")
  ver=$(node -p "require('./$dir/package.json').version")
  [ "$ver" = "$VERSION" ] || { echo "❌ $dir 版本是 $ver，期望 $VERSION" >&2; exit 1; }
  if npm view "$name@$VERSION" version >/dev/null 2>&1; then
    if [ -f "$dir/bin/ttpos" ]; then
      tmp=$(mktemp -d)
      (cd "$tmp" && npm pack "$name@$VERSION" --silent >/dev/null)
      tar -xzf "$tmp"/*.tgz -C "$tmp"
      cmp -s "$tmp/package/bin/ttpos" "$dir/bin/ttpos" || { echo "❌ $name@$VERSION 已发布，内容和本次构建不一致。请升版本号" >&2; exit 1; }
      rm -rf "$tmp"
    fi
    echo "跳过 $name@$VERSION（已发布）"
    continue
  fi
  echo "发布 $name@$VERSION"
  # 加 ./：否则 npm/cli-x 这样的路径会被 npm 当成 GitHub 仓库简写。
  npm publish --access public "./$dir"
done
