import java.io.*;
import java.util.*;

public class Main {
    public static void main(String[] args) throws Exception {
        BufferedReader br = new BufferedReader(new InputStreamReader(System.in));

        String N = br.readLine();

        Map<Character, Integer> map = new HashMap<>();

        for (char c : N.toCharArray()) {
            int value = map.getOrDefault(c, 0);
            map.put(c, value + 1);
        }

        int flipSum =  map.getOrDefault('6', 0) + map.getOrDefault('9', 0);

        map.put('6', flipSum / 2);
        map.put('9', flipSum / 2);
        if (flipSum % 2 == 1) {
            map.put('9', flipSum / 2 + 1);
        }

        int result = map.values().stream().max(Comparator.naturalOrder()).get();

        System.out.print(result);
    }
}
