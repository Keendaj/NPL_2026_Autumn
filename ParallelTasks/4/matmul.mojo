from max.algorithm import parallelize
from std.algorithm import vectorize
from std.random import random_float64
from std.sys import num_logical_cores, simd_width_of
from std.time import perf_counter

comptime N = 1024
comptime W = simd_width_of[DType.float64]()


def random_matrix() -> List[Float64]:
    var m = List[Float64](capacity=N * N)
    for _ in range(N * N):
        m.append(random_float64())
    return m^


def matmul_sequential(a: List[Float64], b: List[Float64], mut c: List[Float64]):
    for i in range(N):
        for k in range(N):
            var aik = a[i * N + k]
            for j in range(N):
                c[i * N + j] += aik * b[k * N + j]


def matmul_parallel(a: List[Float64], b: List[Float64], mut c: List[Float64]):
    var pa = a.unsafe_ptr()
    var pb = b.unsafe_ptr()
    var pc = c.unsafe_ptr()

    def row(i: Int) {imm}:
        for k in range(N):
            var aik = pa[unsafe_offset=i * N + k]

            def axpy[width: Int](j: Int) {imm}:
                var cij = pc.unsafe_load[width=width](i * N + j)
                var bkj = pb.unsafe_load[width=width](k * N + j)
                pc.unsafe_store(i * N + j, cij + aik * bkj)

            vectorize[W](N, axpy)

    parallelize(row, N)


def main():
    var a = random_matrix()
    var b = random_matrix()
    var c1 = List[Float64](length=N * N, fill=0.0)
    var c2 = List[Float64](length=N * N, fill=0.0)

    var start = perf_counter()
    matmul_sequential(a, b, c1)
    var t1 = perf_counter() - start

    start = perf_counter()
    matmul_parallel(a, b, c2)
    var t2 = perf_counter() - start

    var diff: Float64 = 0
    for i in range(N * N):
        diff = max(diff, abs(c1[i] - c2[i]))

    print("Матрицы", N, "x", N, "| SIMD:", W, "| ядер:", num_logical_cores())
    print("Последовательно:", Int(t1 * 1000), "мс")
    print("Параллельно + SIMD:", Int(t2 * 1000), "мс")
    print("Ускорение:", round(t1 / t2, 1), "x")
    print("Максимальное расхождение:", diff)
