module Main where

quicksort :: Ord a => [a] -> [a]
quicksort []     = []
quicksort (p:xs) =
  quicksort [x | x <- xs, x < p]      
  ++ [p] ++                           
  quicksort [x | x <- xs, x >= p]     

main :: IO ()
main = do
  let ints = [5, 3, 8, 1, 9, 2, 7, 4, 6, 0]

  putStrLn "\nQuickSort"
  putStrLn $ "До:    " ++ show ints
  putStrLn $ "После: " ++ show (quicksort ints)

  putStrLn "\nСтроки"
  let strs = ["b", "a", "c", "d"]
  putStrLn $ "До:    " ++ show strs
  putStrLn $ "После: " ++ show (quicksort strs)

  putStrLn "\nГраничные случаи"
  putStrLn $ "Пустой список: " ++ show (quicksort ([] :: [Int]))
  putStrLn $ "Один элемент:  " ++ show (quicksort [0 :: Int])
  putStrLn $ "Дубликаты:     " ++ show (quicksort [3, 1, 3, 2, 1, 3 :: Int])
