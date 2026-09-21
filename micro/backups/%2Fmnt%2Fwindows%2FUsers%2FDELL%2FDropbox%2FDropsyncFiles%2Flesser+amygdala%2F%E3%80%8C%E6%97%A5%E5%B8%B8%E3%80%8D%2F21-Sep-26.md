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
