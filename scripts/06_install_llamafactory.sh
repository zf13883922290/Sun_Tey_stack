#!/usr/bin/env bash
echo "安装 LLaMA-Factory..."
[ -d "$HOME/LLaMA-Factory" ] || \
    git clone https://github.com/hiyouga/LLaMA-Factory.git "$HOME/LLaMA-Factory"
cd "$HOME/LLaMA-Factory"
git pull
pip install -e ".[torch,metrics]" --quiet
echo "✅ 完成。启动: cd ~/LLaMA-Factory && llamafactory-cli webui"
