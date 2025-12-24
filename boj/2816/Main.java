import java.io.*;
import java.util.*;

public class Main {

    static final char UP = '1';
    static final char SELECT = '4';

    public static void main(String[] args) throws Exception {
        BufferedReader br = new BufferedReader(new InputStreamReader(System.in));
        StringBuilder sb = new StringBuilder();
        
        int N = Integer.parseInt(br.readLine());

        int kbs1 = -1, kbs2 = -1;

        for (int i = 0; i < N; i++) {
            String channel = br.readLine();
            if (channel.equals("KBS1")) 
                kbs1 = i;
            if (channel.equals("KBS2")) 
                kbs2 = i;
        }

        move(sb, kbs1, kbs1);

        if ( kbs2 < kbs1)
            kbs2++;

        move(sb, kbs2, kbs2 - 1);
        
        System.out.println(sb.toString());
    }

    private static void move(StringBuilder sb, int up, int select) {
        for (int i = 0; i < up; i++) sb.append(UP);
        for (int i = 0; i < select; i++) sb.append(SELECT);
    }
}
