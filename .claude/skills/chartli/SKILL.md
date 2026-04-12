---
name: chartli
description: Install and use chartli to render terminal charts from numeric text files or stdin.
effort: low
---

# chartli Skill

Use this skill when an agent needs to visualize numeric data in the terminal as ASCII/Unicode/SVG charts.

## CLI usage

```sh
npx chartli --help
```

## What chartli can do

- Render chart types: `ascii`, `spark`, `bars`, `columns`, `heatmap`, `unicode`, `braille`, `svg`
- Read from file path input or stdin when no file is passed
- Control output dimensions with `--width` and `--height`
- Render SVG with `--mode circles|lines`
- Add axis titles with `--x-axis-label` and `--y-axis-label`
- Add custom labels with `--x-labels` and `--series-labels`
- Show raw values with `--data-labels`
- Promote first column to x-axis with `--first-column-x`

## Command templates

From file:

```sh
chartli <file> -t <type> [--width N] [--height N] [--x-axis-label LABEL] [--y-axis-label LABEL] [--data-labels] [--first-column-x]
```

From stdin:

```sh
printf 'x y\n1 10\n2 20\n3 15\n' | chartli -t ascii -w 24 -h 8
```

Per-type examples:

```sh
chartli data.txt -t ascii -w 24 -h 8
chartli data.txt -t spark
chartli data.txt -t bars -w 28
chartli data.txt -t columns -h 8
chartli data.txt -t heatmap
chartli data.txt -t unicode
chartli data.txt -t braille -w 16 -h 6
chartli data.txt -t svg -m lines -w 320 -h 120
```

## Input format

Whitespace-separated numeric rows; optional header row is allowed.

```text
day sales costs profit
1 10 8 2
2 14 9 5
3 12 11 3
```

When `--first-column-x` is set, the first numeric column becomes the x-axis labels.
