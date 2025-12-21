import java.io.*;

public class Main {
    public static void main(String[] args) throws Exception {
        BufferedReader br = new BufferedReader(new InputStreamReader(System.in));
        String s = br.readLine();

        String[] minusSplit = s.split("-");

        int ans = sum(minusSplit[0]);
        for (int i = 1; i < minusSplit.length; i++) {
            ans -= sum(minusSplit[i]);
        }

        System.out.println(ans);
    }

    static int sum(String part) {
        String[] plusSplit = part.split("\\+");
        int res = 0;
        for (String p : plusSplit) {
            res += Integer.parseInt(p);
        }
        return res;
    }
}
