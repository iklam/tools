# See README for more info.

build:
	mvn assembly:assembly -DdescriptorId=jar-with-dependencies

run:
	java -cp ./target/picocli-hello-1.0-SNAPSHOT-jar-with-dependencies.jar app.App 1

bench:
	perf stat -r 10 java -cp target/picocli-hello-1.0-SNAPSHOT-jar-with-dependencies.jar app.App 1 > /dev/null

clean:
	rm -rf target
