

rooms() -> #{
    hall    => {"Зал у входа. Факелы едва горят.",   #{"north" => library, "east" => armory}},
    library => {"Библиотека с истлевшими свитками.", #{"south" => hall, "east" => crypt}},
    armory  => {"Оружейная, всюду ржавые мечи.",     #{"west" => hall, "north" => crypt}},
    crypt   => {"Склеп. Где-то здесь спрятан клад.", #{"west" => library, "south" => armory}}
}.
%   library     crypt
%   hall        armory
main(_) ->
    {ok, Listen} = gen_tcp:listen(8080, [binary, {packet, line}, {active, false}, {reuseaddr, true}]),
    World = spawn(fun() -> world(#{}, #{hall => 0, library => 5, armory => 3, crypt => 10}) end),
    io:format("Подземелье открыто на порту 8080~n"),
    accept(Listen, World).

accept(Listen, World) ->
    {ok, Socket} = gen_tcp:accept(Listen),
    Pid = spawn(fun() -> receive go -> login(Socket, World) end end),
    gen_tcp:controlling_process(Socket, Pid),
    Pid ! go,
    accept(Listen, World).

login(Socket, World) ->
    send(Socket, "Как тебя зовут?"),
    {ok, Line} = gen_tcp:recv(Socket, 0),
    World ! {join, self(), string:trim(unicode:characters_to_list(Line))},
    inet:setopts(Socket, [{active, true}]),
    client(Socket, World).

client(Socket, World) ->
    receive
        {tcp, Socket, Data} ->
            case string:lexemes(unicode:characters_to_list(Data), " \r\n") of
                ["quit"] -> World ! {leave, self()}, gen_tcp:close(Socket);
                Words    -> World ! {cmd, self(), Words}, client(Socket, World)
            end;
        {tcp_closed, Socket} -> World ! {leave, self()};
        {msg, Text} -> send(Socket, Text), client(Socket, World)
    end.

send(Socket, Text) -> gen_tcp:send(Socket, unicode:characters_to_binary([Text, "\n"])).

world(Players, Gold) ->
    receive
        {join, Pid, Name} ->
            P = Players#{Pid => {Name, hall, 0}},
            announce(P, hall, Pid, [Name, " спускается в подземелье."]),
            tell(Pid, describe(hall, P, Gold, Pid)),
            io:format("~ts вошёл~n", [Name]),
            world(P, Gold);
        {leave, Pid} ->
            case maps:take(Pid, Players) of
                {{Name, Room, _}, P} ->
                    announce(P, Room, none, [Name, " покидает подземелье."]),
                    io:format("~ts вышел~n", [Name]),
                    world(P, Gold);
                error -> world(Players, Gold)
            end;
        {cmd, Pid, Words} ->
            {P, G} = command(Words, Pid, maps:get(Pid, Players), Players, Gold),
            world(P, G)
    end.

command(["look"], Pid, {_, Room, _}, Players, Gold) ->
    tell(Pid, describe(Room, Players, Gold, Pid)),
    {Players, Gold};
command(["go", Dir], Pid, {Name, Room, Coins}, Players, Gold) ->
    {_, Exits} = maps:get(Room, rooms()),
    case maps:find(Dir, Exits) of
        {ok, Next} ->
            announce(Players, Room, Pid, [Name, " уходит на ", Dir, "."]),
            P = Players#{Pid := {Name, Next, Coins}},
            announce(P, Next, Pid, [Name, " входит сюда."]),
            tell(Pid, describe(Next, P, Gold, Pid)),
            {P, Gold};
        error ->
            tell(Pid, "Туда не пройти."),
            {Players, Gold}
    end;
command(["take"], Pid, {Name, Room, Coins}, Players, Gold) ->
    case maps:get(Room, Gold) of
        0 ->
            tell(Pid, "Здесь пусто."),
            {Players, Gold};
        N ->
            announce(Players, Room, Pid, [Name, " забирает ", integer_to_list(N), " золота."]),
            tell(Pid, ["Ты берёшь ", integer_to_list(N), " золота. Всего: ", integer_to_list(Coins + N)]),
            {Players#{Pid := {Name, Room, Coins + N}}, Gold#{Room := 0}}
    end;
command(["say" | Words], _, {Name, Room, _}, Players, Gold) ->
    announce(Players, Room, none, [Name, ": ", lists:join(" ", Words)]),
    {Players, Gold};
command(["who"], Pid, _, Players, Gold) ->
    tell(Pid, lists:join("\n", [[N, " — ", atom_to_list(R), ", золото: ", integer_to_list(C)]
                                || {N, R, C} <- maps:values(Players)])),
    {Players, Gold};
command(_, Pid, _, Players, Gold) ->
    tell(Pid, "Команды: look, go <north|south|east|west>, take, say <текст>, who, quit"),
    {Players, Gold}.

describe(Room, Players, Gold, Me) ->
    {Text, Exits} = maps:get(Room, rooms()),
    Others = [N || {Pid, {N, R, _}} <- maps:to_list(Players), R =:= Room, Pid =/= Me],
    [Text,
     "\nВыходы: ", lists:join(", ", maps:keys(Exits)),
     "\nЗолото: ", integer_to_list(maps:get(Room, Gold)),
     "\nРядом: ", case Others of [] -> "никого"; _ -> lists:join(", ", Others) end].

announce(Players, Room, Except, Text) ->
    [tell(Pid, Text) || {Pid, {_, R, _}} <- maps:to_list(Players), R =:= Room, Pid =/= Except],
    ok.

tell(Pid, Text) -> Pid ! {msg, Text}.
