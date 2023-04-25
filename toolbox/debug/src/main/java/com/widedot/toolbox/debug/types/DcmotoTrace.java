package com.widedot.toolbox.debug.types;

import java.io.File;
import java.io.FileNotFoundException;
import java.util.Scanner;

public class DcmotoTrace {

	public static String loop_tag = "6255";
	public static String swap_tag = "82AE";
	public static String gfxlockStart_tag = "6370";
	public static String gfxlockEnd_tag = "63B6";
	public static String irqStart_tag = "FA84";
	public static String irqEnd_tag = "FB18";
	public static String waitStart_tag = "82D8";
	public static String waitEnd_tag = "82ED";
	
	public DcmotoTrace() {
		try {
			Scanner scanner = new Scanner(new File("C:\\Users\\bhrou\\git\\thomson-to8-game-engine\\game-projects\\r-type\\dist\\dcmoto_trace.txt"));

			int cycles = 0;
			
			int loop_cy = 0;
			int irq_cy = 0;
			int unlocked_cy = 0;
			int locked_cy = 0;
			int wait_cy = 0;
			int last_irq = 0;
			int last_irq_length=0;
			
			int totalNoGfx=0;
			int totalGfx=0;
			int totalIrq=0;
			int totalWait = 0;
			int totalCycles=0;
			
			boolean swap = false;
			boolean irq = false;
			boolean locked = false;
			boolean unlocked = false;
			boolean wait = false;
			boolean loop = false;
						
			String line = null;
			
			while (scanner.hasNextLine()) {
				
				line = scanner.nextLine();
				
				if (line.substring(0, 4).equals(loop_tag)) {
					System.out.println("\n*** loop: " + loop_cy + " cycles");
					if (!loop) { // first loop entry
						unlocked = true;
						unlocked_cy = 0;
					}
					loop = true;
					loop_cy = 0;
				}
				
				if (!loop) continue;

				if (line.substring(0, 4).equals(gfxlockStart_tag)) {
					System.out.println("@" + last_irq + " gfx unlocked: " + unlocked_cy + " cycles");
					totalNoGfx += unlocked_cy;
					locked = true;
					locked_cy = 0;
					unlocked = false;
				}
				
				if (line.substring(0, 4).equals(gfxlockEnd_tag)) {
					System.out.println("@" + last_irq + " gfx locked: " + locked_cy + " cycles");
					totalGfx += locked_cy;
					locked = false;
					unlocked = true;
					unlocked_cy = 0;
				}

				if (line.substring(0, 4).equals(waitStart_tag)) {
					System.out.println("*** wait start");
					wait = true;
					wait_cy = 0;
				}
				
				if (line.substring(0, 4).equals(waitEnd_tag)) {
					System.out.println("*** wait: " + (wait_cy-last_irq_length) + " cycles");
					if ((wait_cy-last_irq_length) > 3500 && (wait_cy-last_irq_length) < 16500)
					totalWait += (wait_cy-last_irq_length);
					wait = false;
				}
				
				if (line.substring(0, 4).equals(irqStart_tag)) {
					irq = true;
					irq_cy = 0;
					last_irq = 0;
				}
				
				if (line.substring(0, 4).equals(irqEnd_tag)) {
					System.out.print("    IRQ: " + irq_cy + " cycles");
					last_irq_length = irq_cy;
					totalIrq += irq_cy;
					irq = false;
					
					if (swap) {
						System.out.println(" (swap)");
						swap = false;
					} else {
						System.out.println("");
					}
				}
				
				if (line.substring(0, 4).equals(swap_tag)) {
					if (irq) {
						swap = true;
					} else {
						System.out.println("*** SWAP (outside IRQ)");
					}
				}
				
				if (line.length() >= 44) {
					try {
						cycles = Integer.parseInt(line.substring(42, 44).trim());
					} catch(NumberFormatException e) {
						cycles = 0;
					}
				} else {
					cycles = 0;
				}
				
				if (loop) loop_cy+=cycles;
				if (locked) locked_cy+=cycles;
				if (unlocked) unlocked_cy+=cycles;
				if (wait) wait_cy+=cycles;
				if (irq) irq_cy+=cycles;
				last_irq+=cycles;
				totalCycles += cycles;
			}
			
			System.out.println("Total non gfx : " + totalNoGfx);
			System.out.println("Total gfxlock : " + totalGfx);
			System.out.println("Total Irq : " + totalIrq);
			System.out.println("Total Wait : " + totalWait);
			System.out.println("Total Cycles : " + totalCycles);

			scanner.close();
		} catch (FileNotFoundException e) {
			e.printStackTrace();
		}
	}

}