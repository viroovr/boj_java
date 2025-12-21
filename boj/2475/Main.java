import java.io.*;
import java.util.*;

public class Main {
    public static void main(String[] args) throws Exception {
        BufferedReader br = new BufferedReader(new InputStreamReader(System.in));

        int result = Arrays.stream(br.readLine().split(" "))
                .mapToInt(Integer::parseInt)
                .map(x -> x * x)
                .sum() % 10;

        
        System.out.print(result);
    }
}
