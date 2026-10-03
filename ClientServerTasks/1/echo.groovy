def modes = [
    echo   : { String s -> s },
    upper  : { String s -> s.toUpperCase() },
    reverse: { String s -> s.reverse() },
    count  : { String s -> "${s.length()} символов, ${s.tokenize().size()} слов" },
]

def server = new ServerSocket(8080)
println "Echo server - port 8080"

while (true) {
    def socket = server.accept()
    Thread.start {
        socket.withStreams { input, output ->
            def reader = new BufferedReader(new InputStreamReader(input, 'UTF-8'))
            def writer = new PrintWriter(new OutputStreamWriter(output, 'UTF-8'), true)

            def mode = modes.keySet().toList()[new Random().nextInt(modes.size())]
            writer.println "Режим: $mode"
            println "${socket.remoteSocketAddress} подключился, режим $mode"

            def line
            while ((line = reader.readLine()) != null) {
                writer.println modes[mode](line)
                
                mode = modes.keySet().toList()[new Random().nextInt(modes.size())]
                println "${socket.remoteSocketAddress}: режим $mode"
            }
            println "${socket.remoteSocketAddress} отключился"
        }
    }
}
