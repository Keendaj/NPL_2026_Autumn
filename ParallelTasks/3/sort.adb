with Ada.Text_IO;             use Ada.Text_IO;
with Ada.Float_Text_IO;       use Ada.Float_Text_IO;
with Ada.Command_Line;        use Ada.Command_Line;
with Ada.Real_Time;           use Ada.Real_Time;
with Ada.Containers.Generic_Array_Sort;
with System.Multiprocessors;  use System.Multiprocessors;
with Interfaces;              use Interfaces;

procedure Sort is
   type Arr is array (Positive range <>) of Unsigned_32;
   type Arr_Access is access Arr;
   procedure Std_Sort is new Ada.Containers.Generic_Array_Sort (Positive, Unsigned_32, Arr);

   N    : constant Positive :=
     (if Argument_Count > 0 then Positive'Value (Argument (1)) else 10_000_000);
   Data : constant Arr_Access := new Arr (1 .. N);
   Seq  : constant Arr_Access := new Arr (1 .. N);
   Par  : constant Arr_Access := new Arr (1 .. N);
   Tmp  : constant Arr_Access := new Arr (1 .. N);

   procedure Merge (A : in out Arr; Mid : Positive) is
      T : Arr renames Tmp (A'Range);
      I : Positive := A'First;
      J : Positive := Mid;
   begin
      for K in T'Range loop
         if J > A'Last or else (I < Mid and then A (I) <= A (J)) then
            T (K) := A (I);
            I := I + 1;
         else
            T (K) := A (J);
            J := J + 1;
         end if;
      end loop;
      A := T;
   end Merge;

   procedure Merge_Sort (A : in out Arr; Depth : Natural) is
      Mid : constant Positive := A'First + A'Length / 2;
   begin
      if A'Length < 2 then
         return;
      end if;
      if Depth > 0 then
         declare
            task Left;
            task body Left is
            begin
               Merge_Sort (A (A'First .. Mid - 1), Depth - 1);
            end Left;
         begin
            Merge_Sort (A (Mid .. A'Last), Depth - 1);
         end;
      else
         Merge_Sort (A (A'First .. Mid - 1), 0);
         Merge_Sort (A (Mid .. A'Last), 0);
      end if;
      Merge (A, Mid);
   end Merge_Sort;

   Seed    : Unsigned_64 := 42;
   Threads : Positive := 1;
   Depth   : Natural := 0;
   Start   : Time;
   T1, T2  : Duration;
begin
   for X of Data.all loop
      Seed := Seed xor Shift_Left (Seed, 13);
      Seed := Seed xor Shift_Right (Seed, 7);
      Seed := Seed xor Shift_Left (Seed, 17);
      X := Unsigned_32 (Seed and 16#FFFF_FFFF#);
   end loop;
   while Threads * 2 <= Positive (Number_Of_CPUs) loop
      Threads := Threads * 2;
      Depth := Depth + 1;
   end loop;

   Seq.all := Data.all;
   Start := Clock;
   Merge_Sort (Seq.all, 0);
   T1 := To_Duration (Clock - Start);

   Par.all := Data.all;
   Start := Clock;
   Merge_Sort (Par.all, Depth);
   T2 := To_Duration (Clock - Start);

   Std_Sort (Data.all);

   Put_Line ("Элементов:" & N'Image);
   Put_Line ("Последовательно:" & Integer (T1 * 1000)'Image & " мс");
   Put_Line ("Параллельно на" & Threads'Image & " потоках:" & Integer (T2 * 1000)'Image & " мс");
   Put ("Ускорение: ");
   Put (Float (T1) / Float (T2), Fore => 1, Aft => 1, Exp => 0);
   Put_Line ("x");
   Put_Line ("Результат верный: "
             & (if Seq.all = Data.all and Par.all = Data.all then "да" else "нет"));
end Sort;
