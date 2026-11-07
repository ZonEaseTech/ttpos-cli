#!/bin/sh
# 发布后核对：每个包在 registry 上可下载，且内容和本次构建逐字节一致。
# `npm publish` 成功后 registry/CDN 可能晚几分钟才可见（实测最多约 15 分钟），所以轮询。
set -eu
VERSION=${1:?"用法: verify-published.sh <version> <包目录>..."}; shift
DEADLINE=$(( $(date +%s) + ${VERIFY_TIMEOUT:-1200} ))
for dir in "$@"; do
  name=$(node -p "require('./$dir/package.json').name")
  url="https://registry.npmjs.org/$(printf '%s' "$name" | sed 's#/#%2f#')/$VERSION"
  while :; do
    tarball=$(curl -fsS "$url" 2>/dev/null | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{console.log(JSON.parse(s).dist.tarball)}catch{}})' || true)
    tmp=$(mktemp -d)
    if [ -n "$tarball" ] && curl -fsS -o "$tmp/p.tgz" "$tarball" 2>/dev/null && tar -xzf "$tmp/p.tgz" -C "$tmp"; then
      break
    fi
    rm -rf "$tmp"
    [ "$(date +%s)" -lt "$DEADLINE" ] || { echo "❌ 等待超时：$name@$VERSION 仍不可下载" >&2; exit 1; }
    sleep 15
  done
  if [ -f "$dir/bin/ttpos" ]; then
    cmp -s "$tmp/package/bin/ttpos" "$dir/bin/ttpos" || { echo "❌ $name@$VERSION 二进制与本次构建不一致" >&2; exit 1; }
  else
    cmp -s "$tmp/package/bin/ttpos.js" "$dir/bin/ttpos.js" || { echo "❌ $name@$VERSION 启动脚本与本次构建不一致" >&2; exit 1; }
  fi
  rm -rf "$tmp"
  echo "✓ $name@$VERSION"
done
