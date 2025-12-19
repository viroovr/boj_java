import java.io.*;

public class Main {
    public static void main(String[] args) throws Exception {
        BufferedReader br = new BufferedReader(new InputStreamReader(System.in));

        String sticks = br.readLine();
        
        int result = 0;
        int open = 0;

        for (int i = 0; i < sticks.length() ; i++) {
            char ch = sticks.charAt(i);

            if (ch == ')') {
                open--;
                if (sticks.charAt( i - 1) == '(') {
                    result += open;
                }
                else {
                    result += 1;
                }
            } else {
                open++;
            }
        }

        System.out.print(result);
    }
}
