import java.io.*;
import java.util.*;

public class Main {
    public static void main(String[] args) throws Exception {
        BufferedReader br = new BufferedReader(new InputStreamReader(System.in));
        
        String s = br.readLine();
        List<Character> op = new ArrayList<>();
        List<Integer> nums = new ArrayList<>();

        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < s.length(); i++) {
            char ch = s.charAt(i);

            if (Character.isDigit(ch)) {
                sb.append(ch);
            } else {
                op.add(ch);
                nums.add(Integer.parseInt(sb.toString()));
                sb = new StringBuilder();
            }
        }
        nums.add(Integer.parseInt(sb.toString()));

        int n = nums.size();
        int[][] max = new int[n][n];
        int[][] min = new int[n][n];
        
        for (int i = 0; i < min.length; i++) {
            Arrays.fill(max[i], Integer.MIN_VALUE);
            Arrays.fill(min[i], Integer.MAX_VALUE);
            min[i][i] = max[i][i] = nums.get(i);
        }
        
        for (int len = 1; len < n; len++) {
            for (int i = 0; i + len < n; i++) {
                int j = i + len;
                for (int k = i; k < j; k++) {
                    char operation = op.get(k);

                    switch (operation) {
                        case '+':
                            min[i][j] = Math.min(min[i][j], min[i][k] + min[k + 1][j]);
                            max[i][j] = Math.max(max[i][j], max[i][k] + max[k + 1][j]);
                            break;
                        case '-':
                            min[i][j] = Math.min(min[i][j], min[i][k] - max[k + 1][j]);
                            max[i][j] = Math.max(max[i][j], max[i][k] - min[k + 1][j]);
                    }
                }
            }
        }
        
        System.out.println(min[0][n - 1]);

    }
}
