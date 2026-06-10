#!/usr/bin/env python3
"""
ThkTree 新人环境检查脚本
运行方式: python3 tools/check_onboarding.py
"""

import json
import os
import subprocess
import sys
from pathlib import Path


class Colors:
    GREEN = "\033[92m"
    RED = "\033[91m"
    YELLOW = "\033[93m"
    BLUE = "\033[94m"
    RESET = "\033[0m"


def print_header(title):
    print(f"\n{Colors.BLUE}{'=' * 50}{Colors.RESET}")
    print(f"{Colors.BLUE}  {title}{Colors.RESET}")
    print(f"{Colors.BLUE}{'=' * 50}{Colors.RESET}")


def print_ok(msg):
    print(f"{Colors.GREEN}✓{Colors.RESET} {msg}")


def print_fail(msg, hint=""):
    print(f"{Colors.RED}✗{Colors.RESET} {msg}")
    if hint:
        print(f"  {Colors.YELLOW}→ {hint}{Colors.RESET}")


def print_warn(msg, hint=""):
    print(f"{Colors.YELLOW}⚠{Colors.RESET} {msg}")
    if hint:
        print(f"  {Colors.YELLOW}→ {hint}{Colors.RESET}")


def run_cmd(cmd, capture=True):
    """运行 shell 命令，返回 (success, output)"""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            capture_output=capture,
            text=True,
            timeout=30
        )
        return result.returncode == 0, result.stdout.strip()
    except Exception as e:
        return False, str(e)


def check_skills_lock():
    """检查 skills-lock.json 中声明的技能是否已同步到 .qoder/skills/"""
    print_header("技能配置检查")

    lock_path = Path("skills-lock.json")
    if not lock_path.exists():
        print_fail("skills-lock.json 不存在", "请联系项目维护者获取")
        return False

    try:
        with open(lock_path, "r", encoding="utf-8") as f:
            lock_data = json.load(f)
    except json.JSONDecodeError:
        print_fail("skills-lock.json 格式错误")
        return False

    skills = lock_data.get("skills", {})
    if not skills:
        print_warn("skills-lock.json 中没有声明任何技能")
        return True

    qoder_skills_dir = Path(".qoder/skills")
    all_ok = True

    for skill_name, skill_info in skills.items():
        source = skill_info.get("source", "")

        # 检查 .qoder/skills/ 下是否存在
        skill_file = qoder_skills_dir / skill_name / "SKILL.md"

        if skill_file.exists():
            print_ok(f"技能已同步: {skill_name}")
        else:
            print_fail(
                f"技能未同步: {skill_name}",
                f"请从 {source} 复制到 .qoder/skills/{skill_name}/"
            )
            all_ok = False

    return all_ok


def check_flutter_env():
    """检查 Flutter 环境"""
    print_header("Flutter 环境检查")

    # 检查 flutter 命令
    success, version = run_cmd("flutter --version")
    if success:
        first_line = version.split("\n")[0]
        print_ok(f"Flutter 已安装: {first_line}")
    else:
        print_fail(
            "Flutter 未安装或未加入 PATH",
            "请访问 https://docs.flutter.dev/get-started/install 安装"
        )
        return False

    # 检查 flutter doctor
    success, doctor = run_cmd("flutter doctor")
    if success:
        issues = [line for line in doctor.split("\n") if "✗" in line or "error" in line.lower()]
        if issues:
            for issue in issues[:3]:
                print_warn(f"flutter doctor 发现问题: {issue.strip()}")
            print_warn("建议运行 `flutter doctor` 查看详情并修复")
        else:
            print_ok("flutter doctor 检查通过")
    else:
        print_warn("无法运行 flutter doctor")

    return True


def check_project_deps():
    """检查项目依赖"""
    print_header("项目依赖检查")

    all_ok = True

    # 检查 pubspec.lock 是否存在
    if Path("pubspec.lock").exists():
        print_ok("pubspec.lock 存在 (依赖已解析)")
    else:
        print_fail(
            "pubspec.lock 不存在",
            "请运行 `flutter pub get` 安装依赖"
        )
        all_ok = False

    # 检查 .dart_tool 是否存在
    if Path(".dart_tool/package_config.json").exists():
        print_ok("Dart 包配置已生成")
    else:
        print_fail(
            "Dart 包配置未生成",
            "请运行 `flutter pub get`"
        )
        all_ok = False

    # 检查 ios/Pods 是否存在
    if Path("ios/Pods").exists():
        print_ok("iOS Pods 已安装")
    else:
        print_warn(
            "iOS Pods 未安装",
            "如需 iOS 开发，请运行 `cd ios && pod install`"
        )

    return all_ok


def check_ide_config():
    """检查 IDE 配置"""
    print_header("IDE 配置检查")

    if Path(".idea").exists():
        print_ok("发现 .idea 配置目录 (IntelliJ/Android Studio/Cursor)")
    else:
        print_warn("未找到 .idea 配置目录")

    if Path(".vscode").exists():
        print_ok("发现 .vscode 配置目录")
    else:
        print_warn("未找到 .vscode 配置目录")

    return True


def check_git_config():
    """检查 Git 配置"""
    print_header("Git 配置检查")

    success, _ = run_cmd("git rev-parse --git-dir")
    if success:
        print_ok("Git 仓库已初始化")
    else:
        print_fail("当前目录不是 Git 仓库", "请运行 `git init` 或克隆项目")
        return False

    success, branch = run_cmd("git branch --show-current")
    if success and branch:
        print_ok(f"当前分支: {branch}")
    else:
        print_warn("无法获取当前分支")

    return True


def main():
    print(f"{Colors.BLUE}")
    print("  ████████╗██╗  ██╗██╗  ██╗████████╗██████╗ ███████╗███████╗")
    print("  ╚══██╔══╝██║  ██║██║ ██╔╝╚══██╔══╝██╔══██╗██╔════╝██╔════╝")
    print("     ██║   ███████║█████╔╝    ██║   ██████╔╝█████╗  █████╗  ")
    print("     ██║   ██╔══██║██╔═██╗    ██║   ██╔══██╗██╔══╝  ██╔══╝  ")
    print("     ██║   ██║  ██║██║  ██╗   ██║   ██║  ██║███████╗███████╗")
    print("     ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝")
    print(f"{Colors.RESET}")
    print("  新人环境检查脚本")
    print(f"  项目路径: {os.getcwd()}\n")

    checks = [
        ("技能配置", check_skills_lock),
        ("Flutter 环境", check_flutter_env),
        ("项目依赖", check_project_deps),
        ("IDE 配置", check_ide_config),
        ("Git 配置", check_git_config),
    ]

    results = {}
    for name, check_fn in checks:
        try:
            results[name] = check_fn()
        except Exception as e:
            print_fail(f"检查异常: {e}")
            results[name] = False

    # 汇总
    print_header("检查汇总")
    all_pass = all(results.values())

    for name, passed in results.items():
        status = f"{Colors.GREEN}通过" if passed else f"{Colors.RED}未通过"
        print(f"  {status}{Colors.RESET} {name}")

    print()
    if all_pass:
        print(f"{Colors.GREEN}🎉 所有检查通过！你可以开始开发了。{Colors.RESET}")
        return 0
    else:
        print(f"{Colors.YELLOW}⚠ 部分检查未通过，请根据上方提示修复后再开始开发。{Colors.RESET}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
