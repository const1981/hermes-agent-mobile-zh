#!/usr/bin/env python3
# coding: utf-8
"""
Kotlin import 完整性自检（轻量，无需 Android SDK）。

背景：flutter analyze 只查 Dart，不查 Kotlin。多次在 CI 才暴露
"Unresolved reference" / 漏 import 等问题。本脚本在 push 前扫描 .kt 文件，
找出所有"裸用（未 import）的 Java/Kotlin 标准库类 / 外部类"，避免裸奔。

用法：
  python3 tools/check_kotlin_imports.py <file.kt> [<file2.kt> ...]

退出码：0=无问题，1=发现疑似漏 import（需人工确认是否为误报）。
"""
import re
import sys

# Kotlin 标准库内置（无需 import）白名单
BUILTIN = {
    # kotlin 基础类型
    'String', 'Int', 'Long', 'Boolean', 'Byte', 'Char', 'Float', 'Double', 'Short',
    'UByte', 'UInt', 'ULong', 'UShort', 'Any', 'Unit', 'Nothing', 'Array', 'List',
    'MutableList', 'Set', 'MutableSet', 'Map', 'MutableMap', 'Pair', 'Triple',
    'ByteArray', 'IntArray', 'LongArray', 'FloatArray', 'DoubleArray', 'CharArray',
    'BooleanArray',
    # kotlin 异常 / 容器
    'Exception', 'RuntimeException', 'Throwable', 'IllegalArgumentException',
    'IllegalStateException', 'UnsupportedOperationException', 'SecurityException',
    'NullPointerException', 'IndexOutOfBoundsException', 'NumberFormatException',
    'ClassCastException', 'ArithmeticException', 'NoSuchElementException',
    'Enum', 'Annotation', 'Comparable', 'Iterable', 'Iterator', 'Collection',
    'MutableCollection', 'Sequence', 'Lazy', 'LazyThreadSafetyMode', 'Result',
    'CharSequence', 'StringBuilder', 'StringBuffer', 'Regex', 'MatchResult',
    'MatchGroup', 'Appendable', 'Comparator', 'CharRange', 'IntRange', 'LongRange',
    # java.lang 自动导入（无需写 import）
    'Suppress', 'Thread', 'Runnable', 'Process', 'Math', 'System', 'Runtime',
    'Integer', 'Class', 'Object', 'StackTraceElement', 'Boolean', 'Double',
    'Float', 'Long', 'Enum', 'String', 'StringBuilder',
    # 本文件同 package / 同文件定义的类（无需 import）
    'MainActivity', 'BootstrapManager', 'ProcessManager',
    'GatewayService', 'SetupService', 'TerminalSessionService', 'ArchUtils',
    'Builder', 'BigTextStyle', 'EventSink', 'VERSION', 'Companion',
    # 误报抑制（Android 资源类 / 伴生 / 工具）
    'R', 'VERSION_CODES', 'Companion', 'TODO', 'When', 'KClass', 'Function',
}


def check(path: str):
    with open(path, encoding='utf-8') as f:
        src = f.read()

    # 1) 收集所有 import 的类名
    imported = set()
    for m in re.finditer(r'^\s*import\s+(?:[\w\.]+\.)?([A-Z][\w]*)\s*$', src, re.M):
        imported.add(m.group(1))

    # 2) 收集本文件定义的类名（class/object/interface/enum/typealias/fun）
    defined = set(re.findall(
        r'\b(?:class|object|interface|enum\s+class|typealias|fun|val|var|const\s+val)\s+([A-Z][\w]*)', src))

    # 3) 找"类型/构造器用法"位置的大写类名
    usage = set()
    # ClassName(  /  ClassName.  /  ClassName?  /  ClassName:  /  ClassName<  /  ClassName,
    usage |= set(re.findall(r'\b([A-Z][A-Za-z0-9_]*)\s*(?:\(|\.|\?|:|<)', src))
    # , ClassName   /  as ClassName
    usage |= set(re.findall(r'(?:,|\bas)\s+([A-Z][A-Za-z0-9_]*)\b', src))

    problems = []
    for c in sorted(usage):
        if c in BUILTIN or c in imported or c in defined:
            continue
        problems.append(c)
    return problems


def main():
    if len(sys.argv) < 2:
        print('usage: check_kotlin_imports.py <file.kt> [...]')
        sys.exit(2)
    total = 0
    for p in sys.argv[1:]:
        probs = check(p)
        if probs:
            total += len(probs)
            print(f'[!] {p}')
            for c in probs:
                print(f'    - 疑似漏 import: {c}')
        else:
            print(f'[OK] {p}')
    if total:
        print(f'\n发现 {total} 处疑似漏 import（部分为误报，请人工确认）')
        sys.exit(1)
    print('\n未发现明显漏 import。')
    sys.exit(0)


if __name__ == '__main__':
    main()
