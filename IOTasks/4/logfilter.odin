package main

import "core:fmt"
import "core:os"
import "core:strings"

Options :: struct {
	path:        string,
	out_path:    string,
	keywords:    []string,
	levels:      []string,
	match_all:   bool,
	ignore_case: bool,
	invert:      bool,
	numbered:    bool,
	stats:       bool,
}

usage :: proc() {
	fmt.println("Фильтрация логов по ключевым словам.")
	fmt.println("Использование: logfilter <файл> [опции]")
	fmt.println("  -k=сл1,сл2   ключевые слова (по умолчанию совпадает любое)")
	fmt.println("  -all         строка должна содержать все ключевые слова")
	fmt.println("  -level=A,B   оставлять только строки с такими уровнями (ERROR, WARN, ...)")
	fmt.println("  -i           игнорировать регистр ключевых слов")
	fmt.println("  -v           инвертировать отбор")
	fmt.println("  -nonum       не печатать номера строк")
	fmt.println("  -out=файл    записать результат в файл вместо консоли")
	fmt.println("  -stats       показать статистику по ключевым словам")
}

main :: proc() {
	args := os.args[1:]
	if len(args) == 0 {
		usage()
		os.exit(1)
	}

	opt := Options {
		numbered = true,
	}

	for arg in args {
		switch {
		case arg == "-h" || arg == "--help":
			usage()
			os.exit(0)
		case arg == "-all":
			opt.match_all = true
		case arg == "-i":
			opt.ignore_case = true
		case arg == "-v":
			opt.invert = true
		case arg == "-nonum":
			opt.numbered = false
		case arg == "-stats":
			opt.stats = true
		case strings.has_prefix(arg, "-k="):
			opt.keywords = strings.split(arg[3:], ",")
		case strings.has_prefix(arg, "-level="):
			opt.levels = strings.split(strings.to_upper(arg[7:]), ",")
		case strings.has_prefix(arg, "-out="):
			opt.out_path = arg[5:]
		case strings.has_prefix(arg, "-"):
			fmt.eprintf("Неизвестная опция: %s\n", arg)
			os.exit(1)
		case:
			opt.path = arg
		}
	}

	if opt.path == "" {
		fmt.eprintln("Не указан файл лога.")
		os.exit(1)
	}

	data, read_err := os.read_entire_file(opt.path, context.allocator)
	if read_err != nil {
		fmt.eprintf("Не удалось прочитать файл %s: %v\n", opt.path, read_err)
		os.exit(1)
	}
	defer delete(data)

	search_words := make([]string, len(opt.keywords))
	defer delete(search_words)
	for keyword, i in opt.keywords {
		trimmed := strings.trim_space(keyword)
		search_words[i] = opt.ignore_case ? strings.to_lower(trimmed) : strings.clone(trimmed)
	}

	word_counts := make([]int, len(opt.keywords))
	defer delete(word_counts)

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)

	lines := strings.split_lines(string(data))
	defer delete(lines)

	total, kept := 0, 0

	for raw, index in lines {
		line := strings.trim_right(raw, "\r")
		if strings.trim_space(line) == "" {
			continue
		}
		total += 1

		lower := strings.to_lower(line)
		upper := strings.to_upper(line)
		search_line := opt.ignore_case ? lower : line

		keep := matches_keywords(search_line, search_words, opt.match_all) && matches_level(upper, opt.levels)
		if opt.invert {
			keep = !keep
		}

		if keep {
			kept += 1
			for word, i in search_words {
				if word != "" && strings.contains(search_line, word) {
					word_counts[i] += 1
				}
			}
			if opt.numbered {
				fmt.sbprintf(&builder, "%d: %s\n", index + 1, line)
			} else {
				fmt.sbprintf(&builder, "%s\n", line)
			}
		}

		delete(lower)
		delete(upper)
	}

	result := strings.to_string(builder)

	if opt.out_path != "" {
		if write_err := os.write_entire_file(opt.out_path, transmute([]byte)result); write_err != nil {
			fmt.eprintf("Не удалось записать файл %s: %v\n", opt.out_path, write_err)
			os.exit(1)
		}
		fmt.printf("Записано строк: %d -> %s\n", kept, opt.out_path)
	} else {
		fmt.print(result)
	}

	if opt.stats {
		fmt.println("--- статистика ---")
		fmt.printf("непустых строк: %d\n", total)
		fmt.printf("отобрано:       %d\n", kept)
		for keyword, i in opt.keywords {
			fmt.printf("  %s: %d\n", strings.trim_space(keyword), word_counts[i])
		}
	}
}

matches_keywords :: proc(line: string, words: []string, match_all: bool) -> bool {
	if len(words) == 0 {
		return true
	}
	hits := 0
	for word in words {
		if word != "" && strings.contains(line, word) {
			hits += 1
		}
	}
	return match_all ? hits == len(words) : hits > 0
}

matches_level :: proc(upper_line: string, levels: []string) -> bool {
	if len(levels) == 0 {
		return true
	}
	for level in levels {
		trimmed := strings.trim_space(level)
		if trimmed != "" && strings.contains(upper_line, trimmed) {
			return true
		}
	}
	return false
}
