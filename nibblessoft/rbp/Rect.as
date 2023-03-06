package nibblessoft.rbp
{
	public class Rect
	{
		public var x:int;
		public var y:int;
		public var width:int;
		public var height:int;
		
		public function Rect(x:int = 0, y:int = 0, width:int = 0, height:int = 0) {
			this.x = x;
			this.y = y;
			this.width = width;
			this.height = height;
		}
		
		public function copyFrom(rect:Rect):void {
			this.x = rect.x;
			this.y = rect.y;
			this.width = rect.width;
			this.height = rect.height;
		}
	}
}