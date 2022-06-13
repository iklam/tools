package app;

import picocli.CommandLine;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;
import picocli.CommandLine.Parameters;
import java.util.concurrent.Callable;

@Command(name = "hello", mixinStandardHelpOptions = true, version = "hello 1.0",
         description = "Prints a message to STDOUT.")

class App implements Callable<Integer> {

    @Parameters(index = "0", description = "The number of lines to print.")
    private int num;

    @Option(names = {"-m", "--message"}, description = "Alternative message")
    private String message = "Hello";

    @Override
    public Integer call() throws Exception { // your business logic goes here...
        for (int i=0; i<num; i++) {
            System.out.println(message);
        }
        return 0;
    }

    // this example implements Callable, so parsing, error handling and handling user
    // requests for usage help or version help can be done with one line of code.
    public static void main(String... args) {
        int exitCode = new CommandLine(new App()).execute(args);
        System.exit(exitCode);
    }
}
