import java.io.*;
import java.util.*;

public class Main {
    public static void main(String[] args) throws Exception {
        BufferedReader br = new BufferedReader(new InputStreamReader(System.in));

        char[] sticks = br.readLine().toCharArray();
        Stack<String> st = new Stack<>();
        
        int result = 0;
        
        for (char c : sticks) {
            String element = String.valueOf(c);
            if (c == ')') {
                if (st.peek().equals("(")) {
                    st.pop();
                    if (!st.empty()) {
                        try {
                            int count = Integer.parseInt(st.peek());
                            st.pop();
                            element = String.valueOf(count + 1);
                        } catch (NumberFormatException ex) {
                            element = "2";
                        }
                    } else {
                        continue;
                    }
                }
                else {
                    try {
                        int count = Integer.parseInt(st.peek());
                        st.pop();
                        st.pop();
                        if (!st.empty()) {
                            try {
                                int count2 = Integer.parseInt(st.peek());
                                st.pop();
                                element = String.valueOf(count + count2 - 1);
                            } catch (NumberFormatException ex) {
                                element = String.valueOf(count);
                            }
                            result += count;
                        } else {
                            result += count;
                            continue;
                        }
                    } catch (NumberFormatException ex) {
                    }
                }
            }
            st.add(element);
        }

        System.out.print(result);
    }
}
