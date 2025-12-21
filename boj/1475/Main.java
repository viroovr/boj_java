import java.io.BufferedReader;
import java.io.InputStreamReader;

public class Main {
    public static void main(String[] args) throws Exception {
        BufferedReader br = new BufferedReader(new InputStreamReader(System.in));

        String N = br.readLine();

        int[] cnt = new int[10];

        for (char c : N.toCharArray()) {
            cnt[c - '0']++;
        }

        int sixNine = cnt[6] + cnt[9];
        
        cnt[6] = (sixNine % 2 == 1) ? (sixNine / 2) + 1 : sixNine / 2;
        cnt[9] = 0;

        int answer = 0;
        for (int i = 0; i < 10; i ++) {
            answer = Math.max(answer, cnt[i]);
        }

        System.out.print(answer);
    }
}
