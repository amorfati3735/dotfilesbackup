import java.util.Scanner;
import java.util.InputMismatchException
class InvalidEmailException extends Exception{
	public InvalidEmailException(String message){
		super(message);
		
	}}
class Main{
public void validate(String ip) throws InvalidEmailException{
		if ((ip.indexOf("@"))==-1) throw new InvalidEmailException("no @");
		if((ip.indexOf("@"))==0) throw new InvalidEmailException("l1 is @");
		if((ip.indexOf("@"))==ip.length()-1) throw new InvalidEmailException("last is @");
		if((ip.indexOf("."))==0) throw new InvalidEmailException("no period");
		if((ip.indexOf(" "))==0) throw new InvalidEmailException("l1 is whitespace");
		if((ip.indexOf(" "))==ip.length()-1) throw new InvalidEmailException("last is whitespace");
		


	}

	public static void main(String[] args){
		Scanner sc=new Scanner(System.in);
		String ip=sc.next();
		Main ob=new Main();
		try{
			ob.validate(ip);			
			}
			catch(InvalidEmailException e){
				System.out.println("erro1r"+ e.getMessage());
			}
		}
	}


































multithreading

exception handling:
	import java.util.InputMismatchException;
	class CustException extends Exception{
		public CustException(String msg){
			super(msg);
		}
	}
	class Main{
		psvm(){
			try{
				risky code
				if(cond) throw new CustException("msgggg");
			}
			catch(CustException e){
				sopln(e.getMessage())
			}
			catch(InputMismatchException e){
				sopn(e.)
			}
		}
	}

	throw vs throws
	
packages
