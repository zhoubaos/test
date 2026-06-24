#!/bin/bash
set -euo pipefail

# 功能：合并指定分支到主分支（默认main），并压缩指定分支的提交历史记录
# 无参数：合并当前分支，手动填提交信息
# 1个参数：视为提交信息，分支取当前分支
# 2个及以上参数：第一个分支，剩余拼接为提交信息
# example：npm run merge-branch dev "feat: 更新xxx功能"

# ====================== 配置区 ======================
MAIN_BRANCH="main"
# ====================================================

# 颜色输出函数
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # 无颜色

print_info() { echo -e "${GREEN}[INFO] $1${NC}"; }
print_warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
print_err()  { echo -e "${RED}[ERROR] $1${NC}"; }

# 解析入参逻辑
TARGET_BRANCH=""
COMMIT_MSG=""
if [[ $# -eq 0 ]]; then
    # 无参数：合并当前分支，手动填备注
    TARGET_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    print_warn "未传入任何参数，自动使用当前分支：${TARGET_BRANCH}"
elif [[ $# -eq 1 ]]; then
    # 单个参数：视为提交信息，分支取当前分支
    TARGET_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    COMMIT_MSG="$1"
    print_warn "仅传入1个参数，识别为提交信息；合并当前分支：${TARGET_BRANCH}"
    print_info "提交信息：$COMMIT_MSG"
elif [[ $# -ge 2 ]]; then
    # 两个及以上参数：第一个分支，剩余拼接为提交信息
    TARGET_BRANCH="$1"
    shift
    COMMIT_MSG="$*"
    print_info "指定合并分支：${TARGET_BRANCH}"
    print_info "提交信息：$COMMIT_MSG"
fi

# 检查是否在git仓库
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    print_err "当前目录不是Git仓库，请切换到项目根目录执行脚本！"
    exit 1
fi

# 检查目标分支是否存在
if ! git rev-parse --verify "origin/${TARGET_BRANCH}" >/dev/null 2>&1 && ! git rev-parse --verify "${TARGET_BRANCH}" >/dev/null 2>&1; then
    print_err "分支 ${TARGET_BRANCH} 本地/远程均不存在，请核对分支名称！"
    exit 1
fi

# 检查工作区未提交修改
if [[ -n $(git status --porcelain) ]]; then
    print_warn "检测到工作区存在未提交修改："
    git status --porcelain
    read -p "是否自动stash暂存变更？(y/N) " stash_confirm
    if [[ "$stash_confirm" == "y" || "$stash_confirm" == "Y" ]]; then
        git stash push -m "auto-stash before squash merge ${TARGET_BRANCH}"
        print_info "已暂存本地修改，合并完成后执行 git stash pop 恢复"
    else
        print_err "存在未提交代码，终止合并！请先提交/储藏代码后重试"
        exit 1
    fi
fi

# 切换main并拉取最新
print_info "切换至 ${MAIN_BRANCH} 分支并同步远程最新代码..."
git checkout "${MAIN_BRANCH}"
git pull origin "${MAIN_BRANCH}"

# 拉取目标分支最新
print_info "同步远程 ${TARGET_BRANCH} 分支代码..."
git fetch origin "${TARGET_BRANCH}:${TARGET_BRANCH}"

# squash合并
print_info "开始 squash 合并 ${TARGET_BRANCH}，压缩所有提交记录..."
if git merge --squash "${TARGET_BRANCH}"; then
    if [[ -n "$COMMIT_MSG" ]]; then
        git commit -m "$COMMIT_MSG"
    else
        print_info "未指定提交信息，打开编辑器手动填写合并备注"
        git commit
    fi
    print_info "合并提交完成！main仅保留一条合并记录，无原分支细碎提交"
    echo "最新合并提交："
    git log -1 --oneline
else
    # 冲突提示
    print_err "合并出现代码冲突，请手动解决冲突文件后执行："
    echo "  1. 解决所有冲突文件后 git add ."
    if [[ -n "$COMMIT_MSG" ]]; then
        echo "  2. git commit -m \"$COMMIT_MSG\""
    else
        echo "  2. git commit 手动填写合并备注"
    fi
    echo "  3. 如需放弃本次合并：git merge --abort"
    exit 2
fi

print_info "操作全部结束！如需推送至远程main执行：git push origin ${MAIN_BRANCH}"