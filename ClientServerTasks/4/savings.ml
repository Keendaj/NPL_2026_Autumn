let rec grow balance monthly rate months =
  if months = 0 then balance
  else grow (balance *. (1. +. rate /. 1200.) +. monthly) monthly rate (months - 1)

let handle ic oc =
  output_string oc "Введите: начальная_сумма взнос_в_месяц ставка_%_годовых лет\n";
  flush oc;
  try
    while true do
      let numbers =
        input_line ic |> String.trim |> String.split_on_char ' '
        |> List.filter (( <> ) "") |> List.map float_of_string_opt
      in
      (match numbers with
       | [ Some start; Some monthly; Some rate; Some years ] ->
         let months = int_of_float (years *. 12.) in
         let total = grow start monthly rate months in
         let invested = start +. (monthly *. float months) in
         Printf.fprintf oc "Итог: %.2f (вложено %.2f, проценты %.2f)\n" total invested
           (total -. invested)
       | _ -> output_string oc "Нужно 4 числа, например: 10000 5000 12 3\n");
      flush oc
    done
  with End_of_file -> ()

let () =
  print_endline "Калькулятор накоплений слушает порт 5004";
  Unix.establish_server handle (Unix.ADDR_INET (Unix.inet_addr_any, 5004))
