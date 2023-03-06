package nibblessoft.rbp
{
	/** MaxRectsBinPack implements the MAXRECTS data structure and different bin packing
	 *  algorithms that use this structure.<br>*/
	public class MaxRectsBinPack
	{
		
		/** The BLSF option of the <em>Free Rect Choice Heuristic</em> (FRCH).<br>
		 *  <b>FRCH</b>: Specifies the different heuristic rules that can be used when deciding where to place a new rectangle.<br>
		 *  <b>BSSF</b>: Positions the rectangle against the short side of a free rectangle into which it fits the best.*/
		public const FRCH_RectBestShortSideFit:int = 0;
		
		/** The BLSF option of the <em>Free Rect Choice Heuristic</em> (FRCH).<br>
		 *  <b>FRCH</b>: Specifies the different heuristic rules that can be used when deciding where to place a new rectangle.<br>
		 *  <b>BLSF</b>: Positions the rectangle against the long side of a free rectangle into which it fits the best.*/
		public const FRCH_RectBestLongSideFit:int = 1;
		
		/** The BAF option of the <em>Free Rect Choice Heuristic</em> (FRCH).<br>
		 *  <b>FRCH</b>: Specifies the different heuristic rules that can be used when deciding where to place a new rectangle.<br>
		 *  <b>BAF</b>: Positions the rectangle into the smallest free rect into which it fits.*/
		public const FRCH_RectBestAreaFit:int = 2;
		
		/** The BL option of the <em>Free Rect Choice Heuristic</em> (FRCH).<br>
		 * <b>FRCH</b>: Specifies the different heuristic rules that can be used when deciding where to place a new rectangle.<br>
		 * <b>BL: Does the Tetris placement.*/
		public const FRCH_RectBottomLeftRule:int = 3;
		
		/** The CP option of the <em>Free Rect Choice Heuristic</em> (FRCH).<br>
		 *  <b>FRCH</b>: Specifies the different heuristic rules that can be used when deciding where to place a new rectangle.<br>
		 *  <b>CP</b>: Choosest the placement where the rectangle touches other rects as much as possible.*/
		public const FRCH_RectContactPointRule:int = 4;
		
		
		
		/** Instantiates a bin of the given size. */
		public function MaxRectsBinPack(width:int, height:int) {
			init(width, height);
		}
		
		/** (Re)initializes the packer to an empty bin of width x height units. Call whenever
		 *  you need to restart with a new bin.*/
		public function init(width:int, height:int):void {
			_binWidth = width;
			_binHeight = height;
			
			var rect:Rect = new Rect(0, 0, _binWidth, _binHeight);
			
			// clears out the vector
			_usedRectangles = new Vector.<Rect>();
			_freeRectangles = new Vector.<Rect>();
			
			_freeRectangles.push(rect);
		}
		
		/** Inserts the given list of rectangles in an offline/batch mode, possibly rotated.
		 *  @param rects The list of rectangles to insert. This vector will be destroyed in the process.
		 *  @param method The rectangle placement rule to use when packing.
		 *  @return the packed rectangles. The indices will not correspond to that of rects.*/
		public function batchInsert(rects:Vector.<RectSize>, method:int):void {
			
			while(rects.length > 0)
			{
				var bestScore1:int = int.MAX_VALUE;
				var bestScore2:int = int.MAX_VALUE;
				var bestRectIndex:int = -1;
				var bestNode:Rect;
				
				var rectsCount:int = rects.length;
				for(var i:int = 0; i < rectsCount; ++i)
				{
					
					
					var obj:Object = scoreRect(rects[i].width, rects[i].height, method);
					var newNode:Rect = obj.rect;
					var score1:int = obj.score1;
					var score2:int = obj.score2;
					
					if (score1 < bestScore1 || (score1 == bestScore1 && score2 < bestScore2))
					{
						bestScore1 = score1;
						bestScore2 = score2;
						bestNode = newNode;
						bestRectIndex = i;
					}
				}
				
				if (bestRectIndex == -1)
					return;
				
				placeRect(bestNode);
				//rects.erase(rects.begin() + bestRectIndex);
				rects.splice(bestRectIndex, 1);
			}
		}
			
		
		/** Inserts a single rectangle into the bin, possibly rotated.*/
		public function insert(width:int, height:int, method:int):Rect {
			// The scores are unused in this function. We don't need to know the score after 
			// finding the position.
			
			var obj:Object;
			switch(method)
			{
				case FRCH_RectBestShortSideFit: 
					obj = findPositionForNewNodeBestShortSideFit(width, height);
					break;
				
				case FRCH_RectBottomLeftRule:
					obj = findPositionForNewNodeBottomLeft(width, height);
					break;
				
				case FRCH_RectContactPointRule:
					obj = findPositionForNewNodeContactPoint(width, height);
					break;
				
				case FRCH_RectBestLongSideFit:
					obj = findPositionForNewNodeBestLongSideFit(width, height);
					break;
				
				case FRCH_RectBestAreaFit: 
					obj = findPositionForNewNodeBestAreaFit(width, height);
					break;
			}
			
			var newNode:Rect = obj.rect;
			if (newNode.height == 0)
				return newNode;
			
			var numRectanglesToProcess:int = _freeRectangles.length;
			for(var i:int = 0; i < numRectanglesToProcess; ++i) {
				if (splitFreeNode(_freeRectangles[i], newNode)) {
					//_freeRectangles.erase(_freeRectangles.begin() + i);
					_freeRectangles.splice(i, 1);
					--i;
					--numRectanglesToProcess;
				}
			}
			
			pruneFreeList();
			
			_usedRectangles.push(newNode);
			return newNode;
		}
		
		/** Computes the ratio of used surface area to the total bin area.*/
		public function occupancy():Number {
			var usedSurfaceArea:int = 0,
				usedRectanglesCount:int = _usedRectangles.length;
			
			for(var i:int = 0; i < usedRectanglesCount; ++i)
				usedSurfaceArea += _usedRectangles[i].width * _usedRectangles[i].height;
			
			return Number(usedSurfaceArea) / Number(_binWidth * _binHeight);
		}
		
		
		
		// -------------------------- PRIVATE ------------------------
		private var _binWidth:int;
		private var _binHeight:int;
		
		private var _usedRectangles:Vector.<Rect>;
		private var _freeRectangles:Vector.<Rect>;
		
		/** Computes the placement score for placing the given rectangle with the given method.
		 *  @param score1 [out] The primary placement score will be outputted here.
		 *  @param score2 [out] The secondary placement score will be outputted here. This isu sed to break ties.
		 *  @return This struct identifies where the rectangle would be placed if it were placed.*/
		private function scoreRect(width:int, height:int, method:int):Object {
			
			var score1:int = int.MAX_VALUE;
			var score2:int = int.MAX_VALUE;
			
			var obj:Object;
			switch(method) {
				case FRCH_RectBestShortSideFit: 
					obj = findPositionForNewNodeBestShortSideFit(width, height);
					break;
				
				case FRCH_RectBottomLeftRule:
					obj = findPositionForNewNodeBottomLeft(width, height);
					break;
				
				case FRCH_RectContactPointRule: 
					obj = findPositionForNewNodeContactPoint(width, height); 
					score1 = -score1; // Reverse since we are minimizing, but for contact point score bigger is better.
					break;
				
				case FRCH_RectBestLongSideFit:
					obj = findPositionForNewNodeBestLongSideFit(width, height);
					var tmp:int = obj.score1;
					obj.score1 = obj.score2;
					obj.score2 = tmp;
					break;
				
				case FRCH_RectBestAreaFit:
					obj = findPositionForNewNodeBestAreaFit(width, height);
					break;
			}
			
			var newNode:Rect = obj.rect;
			// Cannot fit the current rectangle.
			if (newNode.height == 0) {
				score1 = int.MAX_VALUE;
				score2 = int.MAX_VALUE;
			}
			
			return {rect:newNode, score1:score1, score2:score2};
		}
		
		/** Places the given rectangle into the bin.*/
		private function placeRect(node:Rect):void {
			var numRectanglesToProcess:int = _freeRectangles.length;
			for (var i:int = 0; i < numRectanglesToProcess; ++i) {
				if (splitFreeNode(_freeRectangles[i], node))
				{
					//freeRectangles.erase(freeRectangles.begin() + i);
					_freeRectangles.splice(i, 1);
					--i;
					--numRectanglesToProcess;
				}
			}
			
			pruneFreeList();
			
			_usedRectangles.push(node);
			//		dst.push_back(bestNode); ///\todo Refactor so that this compiles.
		}
		
		/** Computes the placement score for the -CP variant.*/
		private function contactPointScoreNode(x:int, y:int, width:int, height:int):int {
			var score:int = 0;
			
			if (x == 0 || x + width == _binWidth)
				score += height;
			if (y == 0 || y + height == _binHeight)
				score += width;
			
			var usedRectanglesCount:int = _usedRectangles.length;
			var currentRect:Rect;
			for(var i:int = 0; i < usedRectanglesCount; ++i)
			{
				currentRect = _usedRectangles[i];
				if (currentRect.x == x + width || currentRect.x + currentRect.width == x)
					score += commonIntervalLength(currentRect.y, currentRect.y + currentRect.height, y, y + height);
				if (currentRect.y == y + height || currentRect.y + currentRect.height == y)
					score += commonIntervalLength(currentRect.x, currentRect.x + currentRect.width, x, x + width);
			}
			
			return score;
		}
		
		private function findPositionForNewNodeBottomLeft(width:int, height:int):Object {
			var bestNode:Rect = new Rect();
			
			var bestY:int = int.MAX_VALUE;
			var bestX:int = int.MAX_VALUE;
			
			var freeRectanglesCount:int = _freeRectangles.length;
			var currentRect:Rect;
			for(var i:int = 0; i < freeRectanglesCount; ++i)
			{
				currentRect = _freeRectangles[i];
				var topSideY:int;
				// Try to place the rectangle in upright (non-flipped) orientation.
				if (currentRect.width >= width && currentRect.height >= height)
				{
					topSideY = currentRect.y + height;
					if (topSideY < bestY || (topSideY == bestY && currentRect.x < bestX))
					{
						bestNode.x = currentRect.x;
						bestNode.y = currentRect.y;
						bestNode.width = width;
						bestNode.height = height;
						bestY = topSideY;
						bestX = currentRect.x;
					}
				}
				if (currentRect.width >= height && currentRect.height >= width)
				{
					topSideY = currentRect.y + width;
					if (topSideY < bestY || (topSideY == bestY && currentRect.x < bestX))
					{
						bestNode.x = currentRect.x;
						bestNode.y = currentRect.y;
						bestNode.width = height;
						bestNode.height = width;
						bestY = topSideY;
						bestX = currentRect.x;
					}
				}
			}
			
			return {rect:bestNode, score1:bestY, score2:bestX};
		}
		
		private function findPositionForNewNodeBestShortSideFit(width:int, height:int):Object {
			var bestNode:Rect = new Rect();
			
			var bestShortSideFit:int = int.MAX_VALUE;
			var bestLongSideFit:int = int.MAX_VALUE;
			
			var freeRectanglesCount:int = _freeRectangles.length;
			var currentRect:Rect;
			for(var i:int = 0; i < freeRectanglesCount; ++i)
			{
				currentRect = _freeRectangles[i];
				// Try to place the rectangle in upright (non-flipped) orientation.
				if (currentRect.width >= width && currentRect.height >= height)
				{
					var leftoverHoriz:int = Math.abs(currentRect.width - width);
					var leftoverVert:int = Math.abs(currentRect.height - height);
					var shortSideFit:int = Math.min(leftoverHoriz, leftoverVert);
					var longSideFit:int = Math.max(leftoverHoriz, leftoverVert);
					
					if (shortSideFit < bestShortSideFit || (shortSideFit == bestShortSideFit && longSideFit < bestLongSideFit))
					{
						bestNode.x = currentRect.x;
						bestNode.y = currentRect.y;
						bestNode.width = width;
						bestNode.height = height;
						bestShortSideFit = shortSideFit;
						bestLongSideFit = longSideFit;
					}
				}
				
				if (currentRect.width >= height && currentRect.height >= width)
				{
					var flippedLeftoverHoriz:int = Math.abs(currentRect.width - height);
					var flippedLeftoverVert:int = Math.abs(currentRect.height - width);
					var flippedShortSideFit:int = Math.min(flippedLeftoverHoriz, flippedLeftoverVert);
					var flippedLongSideFit:int = Math.max(flippedLeftoverHoriz, flippedLeftoverVert);
					
					if (flippedShortSideFit < bestShortSideFit || (flippedShortSideFit == bestShortSideFit && flippedLongSideFit < bestLongSideFit))
					{
						bestNode.x = currentRect.x;
						bestNode.y = currentRect.y;
						bestNode.width = height;
						bestNode.height = width;
						bestShortSideFit = flippedShortSideFit;
						bestLongSideFit = flippedLongSideFit;
					}
				}
			}
			return {rect:bestNode, score1:bestShortSideFit, score2:bestLongSideFit};
		}
		
		private function findPositionForNewNodeBestLongSideFit(width:int, height:int):Object {
			var bestNode:Rect = new Rect();
			
			var bestShortSideFit:int = int.MAX_VALUE;
			var bestLongSideFit:int = int.MAX_VALUE;
			
			var freeRectanglesCount:int = _freeRectangles.length;
			var currentRect:Rect;
			for(var i:int = 0; i < freeRectanglesCount; ++i)
			{
				currentRect = _freeRectangles[i];
				var leftoverHoriz:int, leftoverVert:int, shortSideFit:int, longSideFit:int;
				// Try to place the rectangle in upright (non-flipped) orientation.
				if (currentRect.width >= width && currentRect.height >= height)
				{
					leftoverHoriz = Math.abs(currentRect.width - width);
					leftoverVert  = Math.abs(currentRect.height - height);
					shortSideFit  = Math.min(leftoverHoriz, leftoverVert);
					longSideFit   = Math.max(leftoverHoriz, leftoverVert);
					
					if (longSideFit < bestLongSideFit || (longSideFit == bestLongSideFit && shortSideFit < bestShortSideFit))
					{
						bestNode.x = currentRect.x;
						bestNode.y = currentRect.y;
						bestNode.width = width;
						bestNode.height = height;
						bestShortSideFit = shortSideFit;
						bestLongSideFit = longSideFit;
					}
				}
				
				if (currentRect.width >= height && currentRect.height >= width)
				{
					leftoverHoriz = Math.abs(currentRect.width - height);
					leftoverVert  = Math.abs(currentRect.height - width);
					shortSideFit  = Math.min(leftoverHoriz, leftoverVert);
					longSideFit   = Math.max(leftoverHoriz, leftoverVert);
					
					if (longSideFit < bestLongSideFit || (longSideFit == bestLongSideFit && shortSideFit < bestShortSideFit))
					{
						bestNode.x = currentRect.x;
						bestNode.y = currentRect.y;
						bestNode.width = height;
						bestNode.height = width;
						bestShortSideFit = shortSideFit;
						bestLongSideFit = longSideFit;
					}
				}
			}
			
			return {rect:bestNode, score1:bestShortSideFit, score2:bestLongSideFit};
		}
		
		private function findPositionForNewNodeBestAreaFit(width:int, height:int):Object {
			var bestNode:Rect = new Rect();
			
			var bestAreaFit:int = int.MAX_VALUE;
			var bestShortSideFit:int = int.MAX_VALUE;
			
			var freeRectanglesCount:int = _freeRectangles.length;
			var currentRect:Rect;
			for(var i:int = 0; i < freeRectanglesCount; ++i)
			{
				currentRect = _freeRectangles[i];
				var areaFit:int = currentRect.width * currentRect.height - width * height;
				var leftoverHoriz:int, leftoverVert:int, shortSideFit:int;
				// Try to place the rectangle in upright (non-flipped) orientation.
				if (currentRect.width >= width && currentRect.height >= height)
				{
					leftoverHoriz = Math.abs(currentRect.width - width);
					leftoverVert = Math.abs(currentRect.height - height);
					shortSideFit = Math.min(leftoverHoriz, leftoverVert);
					
					if (areaFit < bestAreaFit || (areaFit == bestAreaFit && shortSideFit < bestShortSideFit))
					{
						bestNode.x = currentRect.x;
						bestNode.y = currentRect.y;
						bestNode.width = width;
						bestNode.height = height;
						bestShortSideFit = shortSideFit;
						bestAreaFit = areaFit;
					}
				}
				
				if (currentRect.width >= height && currentRect.height >= width)
				{
					leftoverHoriz = Math.abs(currentRect.width - height);
					leftoverVert = Math.abs(currentRect.height - width);
					shortSideFit = Math.min(leftoverHoriz, leftoverVert);
					
					if (areaFit < bestAreaFit || (areaFit == bestAreaFit && shortSideFit < bestShortSideFit))
					{
						bestNode.x = currentRect.x;
						bestNode.y = currentRect.y;
						bestNode.width = height;
						bestNode.height = width;
						bestShortSideFit = shortSideFit;
						bestAreaFit = areaFit;
					}
				}
			}
			
			return {rect:bestNode, score1:bestAreaFit, score2:bestShortSideFit};
		}
		
		private function findPositionForNewNodeContactPoint(width:int, height:int):Object {
			var bestNode:Rect = new Rect();
			
			var bestContactScore:int = -1;
			
			var freeRectanglesCount:int = _freeRectangles.length;
			var currentRect:Rect;
			for(var i:int = 0; i < freeRectanglesCount; ++i)
			{
				currentRect = _freeRectangles[i];
				var score:int;
				// Try to place the rectangle in upright (non-flipped) orientation.
				if (currentRect.width >= width && currentRect.height >= height)
				{
					score = contactPointScoreNode(currentRect.x, currentRect.y, width, height);
					if (score > bestContactScore)
					{
						bestNode.x = currentRect.x;
						bestNode.y = currentRect.y;
						bestNode.width = width;
						bestNode.height = height;
						bestContactScore = score;
					}
				}
				if (currentRect.width >= height && currentRect.height >= width)
				{
					score = contactPointScoreNode(currentRect.x, currentRect.y, height, width);
					if (score > bestContactScore)
					{
						bestNode.x = currentRect.x;
						bestNode.y = currentRect.y;
						bestNode.width = height;
						bestNode.height = width;
						bestContactScore = score;
					}
				}
			}
			
			return {rect:bestNode, score1:bestContactScore, score2:NaN};
		}
		
		/** @return True if the free node was split.*/
		private function splitFreeNode(freeNode:Rect, usedNode:Rect):Boolean {
			// Test with SAT if the rectangles even intersect.
			if (usedNode.x >= freeNode.x + freeNode.width || usedNode.x + usedNode.width <= freeNode.x ||
				usedNode.y >= freeNode.y + freeNode.height || usedNode.y + usedNode.height <= freeNode.y)
				return false;
			
			var newNode:Rect;
			if (usedNode.x < freeNode.x + freeNode.width && usedNode.x + usedNode.width > freeNode.x)
			{
				// New node at the top side of the used node.
				if (usedNode.y > freeNode.y && usedNode.y < freeNode.y + freeNode.height)
				{
					newNode = new Rect();
					newNode.copyFrom(freeNode);
					newNode.height = usedNode.y - newNode.y;
					_freeRectangles.push(newNode);
				}
				
				// New node at the bottom side of the used node.
				if (usedNode.y + usedNode.height < freeNode.y + freeNode.height)
				{
					newNode = new Rect();
					newNode.copyFrom(freeNode);
					newNode.y = usedNode.y + usedNode.height;
					newNode.height = freeNode.y + freeNode.height - (usedNode.y + usedNode.height);
					_freeRectangles.push(newNode);
				}
			}
			
			if (usedNode.y < freeNode.y + freeNode.height && usedNode.y + usedNode.height > freeNode.y)
			{
				// New node at the left side of the used node.
				if (usedNode.x > freeNode.x && usedNode.x < freeNode.x + freeNode.width)
				{
					newNode = new Rect();
					newNode.copyFrom(freeNode);
					newNode.width = usedNode.x - newNode.x;
					_freeRectangles.push(newNode);
				}
				
				// New node at the right side of the used node.
				if (usedNode.x + usedNode.width < freeNode.x + freeNode.width)
				{
					newNode = new Rect();
					newNode.copyFrom(freeNode);
					newNode.x = usedNode.x + usedNode.width;
					newNode.width = freeNode.x + freeNode.width - (usedNode.x + usedNode.width);
					_freeRectangles.push(newNode);
				}
			}
			
			return true;
		}
		
		/** Goes through the free rectangle list and removes any redundant entries.*/
		private function pruneFreeList():void {
			/* 
			///  Would be nice to do something like this, to avoid a Theta(n^2) loop through each pair.
			///  But unfortunately it doesn't quite cut it, since we also want to detect containment. 
			///  Perhaps there's another way to do this faster than Theta(n^2).
			
			if (freeRectangles.size() > 0)
			clb::sort::QuickSort(&freeRectangles[0], freeRectangles.size(), NodeSortCmp);
			
			for(size_t i = 0; i < freeRectangles.size()-1; ++i)
			if (freeRectangles[i].x == freeRectangles[i+1].x &&
			freeRectangles[i].y == freeRectangles[i+1].y &&
			freeRectangles[i].width == freeRectangles[i+1].width &&
			freeRectangles[i].height == freeRectangles[i+1].height)
			{
			freeRectangles.erase(freeRectangles.begin() + i);
			--i;
			}
			*/
			
			/// Go through each pair and remove any rectangle that is redundant.
			for(var i:int = 0; i < _freeRectangles.length; ++i)
				for(var j:int = i+1; j < _freeRectangles.length; ++j) {
					if (isContainedIn(_freeRectangles[i], _freeRectangles[j])) {
						//freeRectangles.erase(freeRectangles.begin()+i);
						_freeRectangles.splice(i, 1);
						--i;
						break;
					}
					if (isContainedIn(_freeRectangles[j], _freeRectangles[i]))
					{
						//freeRectangles.erase(freeRectangles.begin()+j);
						_freeRectangles.splice(j, 1);
						--j;
					}
				}

		}
		
		private function isContainedIn(a:Rect, b:Rect):Boolean
		{
			return a.x >= b.x && a.y >= b.y 
				&& a.x+a.width <= b.x+b.width 
				&& a.y+a.height <= b.y+b.height;
		}
		
		/** Returns 0 if the two intervals i1 and i2 are disjoint, or the length of their overlap otherwise.*/
		private function commonIntervalLength(i1start:int, i1end:int, i2start:int, i2end:int):int
		{
			if (i1end < i2start || i2end < i1start)
				return 0;
			return Math.min(i1end, i2end) - Math.max(i1start, i2start);
		}
	}
}