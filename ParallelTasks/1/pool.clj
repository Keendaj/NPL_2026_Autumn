(defn prime? [^long n]
  (and (> n 1)
       (loop [d 2]
         (cond (> (* d d) n) true
               (zero? (rem n d)) false
               :else (recur (inc d))))))

(defn count-primes [[from to]]
  (count (filter prime? (range from to))))

(def step 500000)
(def jobs (atom (for [i (range 20)] [(* i step) (* (inc i) step)])))

(defn say [& words]
  (locking *out* (apply println words)))

(defn take-job! []
  (first (first (swap-vals! jobs rest))))

(defn work [done id]
  (if-let [[from to :as job] (take-job!)]
    (let [found (count-primes job)]
      (say "Воркер" id "проверил" from ".." to "-> простых:" found)
      (recur (conj done found) id))
    done))

(let [n (Integer/parseInt (or (first *command-line-args*) "4"))
      workers (vec (repeatedly n #(agent [])))
      start (System/nanoTime)]
  (doseq [[i w] (map-indexed vector workers)]
    (send-off w work (inc i)))
  (apply await workers)
  (println)
  (doseq [[i w] (map-indexed vector workers)]
    (println "Воркер" (inc i) "выполнил задач:" (count @w)))
  (println "Всего простых:" (reduce + (mapcat deref workers)))
  (println "Время:" (quot (- (System/nanoTime) start) 1000000) "мс")
  (shutdown-agents))
