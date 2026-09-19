:- initialization(main, main).

:- dynamic score/1.

scene(gate,
      "Ты стоишь перед воротами обсерватории. На замке вопрос:",
      "Сколько будет 2 + 2 * 2?",
      ["6"],
      "Умножение выполняется раньше сложения.",
      hall).

scene(hall,
      "Пол обсерватории выложен плитками с числами 1, 1, 2, 3, 5, 8. Следующая плита пустая.",
      "Какое число должно быть на пустой плите?",
      ["13"],
      "Числа фибоначчи.",
      library).

scene(library,
      "Призрак преграждает путь и вопрошает:",
      "Как называется структура данных, работающая по принципу LIFO?",
      ["стек", "stack"],
      "Последний пришёл - первый ушёл, почти как очередь.",
      dome).

scene(dome,
      "Телескоп направлен в небо, рядом лежит журнал наблюдений:",
      "Сколько планет в Солнечной системе по современной классификации?",
      ["8"],
      "Плутон больше не планета увы.",
      crypt).

scene(crypt,
      "На двери наружу последняя надпись: ",
      "Сколько бит в одном байте?",
      ["8"],
      "Вам что-то говорит число 256?",
      finish).

final(finish).

main :-
    retractall(score(_)),
    assertz(score(0)),
    intro,
    play(gate),
    score(Score),
    total(Total),
    format("~nИтог: ~w из ~w.~n", [Score, Total]),
    verdict(Score, Total).

intro :-
    format("~nОБСЕРВАТОРИЯ~n"),
    format("Отвечай на вопросы, чтобы двигаться дальше. На каждый вопрос две попытки.~n").

play(Id) :-
    final(Id), !,
    format("~nТяжёлая дверь поддаётся, и ты выходишь наружу.~n").
play(Id) :-
    scene(Id, Desc, Question, Answers, Hint, Next),
    format("~n~w~n", [Desc]),
    ask(Question, Answers, Hint, 2, Correct),
    ( Correct == true -> add_score(1) ; true ),
    play(Next).

ask(Question, Answers, Hint, Attempts, Correct) :-
    format("~w~n> ", [Question]),
    read_line_to_string(user_input, Raw),
    (   Raw == end_of_file
    ->  format("~nВыход из квеста.~n"), halt
    ;   normalize(Raw, Answer),
        (   memberchk(Answer, Answers)
        ->  format("Верно!~n"), Correct = true
        ;   Attempts > 1
        ->  format("Неверно. Подсказка: ~w~n", [Hint]),
            Left is Attempts - 1,
            ask(Question, Answers, Hint, Left, Correct)
        ;   Answers = [Right|_],
            format("Снова мимо. Правильный ответ: ~w~n", [Right]),
            Correct = false
        )
    ).

normalize(Raw, Answer) :-
    string_lower(Raw, Lower),
    normalize_space(string(Answer), Lower).

add_score(N) :-
    retract(score(S)),
    S1 is S + N,
    assertz(score(S1)).

total(Total) :-
    aggregate_all(count, scene(_, _, _, _, _, _), Total).

verdict(Score, Total) :-
    Score =:= Total, !,
    format("Идеально: обсерватория раскрыла все свои тайны.~n").
verdict(Score, Total) :-
    Score * 2 >= Total, !,
    format("Неплохо, но пара загадок осталась неразгаданной.~n").
verdict(_, _) :-
    format("Похоже, стоит пройти квест ещё раз.~n").
