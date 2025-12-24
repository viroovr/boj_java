import java.io.*;
import java.util.*;

public class Main {

    public static void main(String[] args) throws Exception {
        BufferedReader br = new BufferedReader(new InputStreamReader(System.in));
        StringBuilder sb = new StringBuilder();
        
        int N = Integer.parseInt(br.readLine());

        int kbs1 = 0, kbs2 = 0;
        for (int i = 0; i < N; i++) {
            String channel = br.readLine();
            if (channel.equals("KBS1")) {
                kbs1 = i;
            }
            else if (channel.equals("KBS2")) {
                kbs2 = i;

            }
        }
        // System.out.println(kbs1);
        // System.out.println(kbs2);
        
        for (int i = 0; i < kbs1; i++) {
            sb.append("1");
        }
        for (int i = 0; i < kbs1; i++) {
            sb.append("4");
        }

        if ( kbs2 < kbs1) {
            kbs2++;
        }
        if (kbs2 != 1) {
            for (int i = 0; i < kbs2; i++) {
                sb.append("1");
            }
            for (int i = 1; i < kbs2; i++) {
                sb.append("4");
            }
        }
        
        // System.out.println(sb.length());
        System.out.println(sb.toString());
    }
}
