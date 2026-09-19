structure LongestRepeatingReplacement =
struct

  fun charIndex c = Char.ord c - Char.ord #"A"

  fun solve (s : string) (k : int) : int =
    let
      val n = String.size s
      val counts = Array.array (26, 0)

      fun loop (left : int, right : int, maxCount : int, best : int) : int =
        if right = n then
          best
        else
          let
            val idx = charIndex (String.sub (s, right))
            val ()  = Array.update (counts, idx, Array.sub (counts, idx) + 1)
            val maxCount' = Int.max (maxCount, Array.sub (counts, idx))
            val windowLen = right - left + 1
          in
            if windowLen - maxCount' > k then
              let
                val leftIdx = charIndex (String.sub (s, left))
                val ()      = Array.update (counts, leftIdx, Array.sub (counts, leftIdx) - 1)
              in
                loop (left + 1, right + 1, maxCount', best)
              end
            else
              loop (left, right + 1, maxCount', Int.max (best, windowLen))
          end
    in
      if n = 0 then 0 else loop (0, 0, 0, 0)
    end

end

fun report (s : string, k : int, expected : int) =
  let
    val got    = LongestRepeatingReplacement.solve s k
    val status = if got = expected then "OK  " else "FAIL"
  in
    print (String.concat
      [status, s, " k=", Int.toString k,
       " -> ", Int.toString got, "\n"])
  end

val () = report ("XYYX",    2, 4)   
val () = report ("AAABABB", 1, 5)  
val () = report ("ABAB",    2, 4)   
val () = report ("AABABBA", 1, 4)   
val () = report ("A",       0, 1)  
val () = report ("AAAA",    0, 4) 