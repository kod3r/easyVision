-----------------------------------------------------------------------------
{- |
Module      :  ImagProc.Polyline
Copyright   :  (c) Alberto Ruiz 2007
License     :  GPL-style

Maintainer  :  Alberto Ruiz (aruiz at um dot es)
Stability   :  very provisional
Portability :  hmm...

Some operations with polylines.

-}
-----------------------------------------------------------------------------

module ImagProc.Polyline (
-- * Operations
    Polyline(..),
    perimeter,
    orientation,
-- * Extraction
    rawContour,
    contours
)
where

import ImagProc.Images
import ImagProc.ImageProcessing(copy8u,maxIndx8u,floodFill8u, binarize8u)
import ImagProc.Ipp.Core
import Foreign.C.Types(CUChar)
import Foreign
import Debug.Trace

debug x = trace (show x) x

data Polyline = Closed [Point]
              | Open   [Point]

distPoints (Point a b) (Point x y) = (a-x)^2+(b-y)^2

-- | (for an open polyline is the length)
perimeter :: Polyline -> Double
perimeter (Open l) = perimeter' l
perimeter (Closed l) = perimeter' (last l:l)

perimeter' [_] = 0
perimeter' (a:b:rest) = distPoints a b + perimeter' (b:rest)

-- | Oriented area of a closed polyline. The clockwise sense is positive in the x-y world frame (\"floor\",z=0) and negative in the camera frame.
--
-- area = abs.orientation.
orientation :: Polyline -> Double
orientation (Open _) = error "undefined orientation of open polyline"
orientation (Closed l) = -0.5 * orientation' (last l:l)

orientation' [_] = 0
orientation' (Point x1 y1:r@(Point x2 y2:_)) = x1*y2-x2*y1 + orientation' r

--------------------------------------------------------------

data Dir = ToRight | ToLeft | ToDown | ToUp
nextPos :: ImageGray -> CUChar -> (Pixel,Dir) -> (Pixel,Dir)

nextPos im v (Pixel r c, ToRight) = case (a,b) of
    (False,False) -> (Pixel (r+1) c, ToDown)
    (False,True)  -> (Pixel r (c+1), ToRight)
    _             -> (Pixel (r-1) c, ToUp)
  where
    a = val8u im (Pixel (r-1) c) == v
    b = val8u im (Pixel r c) == v

nextPos im v (Pixel r c, ToDown) = case (a,b) of
    (False,False) -> (Pixel r (c-1), ToLeft)
    (False,True)  -> (Pixel (r+1) c, ToDown)
    _             -> (Pixel r (c+1), ToRight)
  where
    a = val8u im (Pixel r c) == v
    b = val8u im (Pixel r (c-1)) == v

nextPos im v (Pixel r c, ToLeft) = case (a,b) of
    (False,False) -> (Pixel (r-1) c, ToUp)
    (False,True)  -> (Pixel r (c-1), ToLeft)
    _             -> (Pixel (r+1) c, ToDown)
  where
    a = val8u im (Pixel r (c-1)) == v
    b = val8u im (Pixel (r-1) (c-1)) == v

nextPos im v (Pixel r c, ToUp) = case (a,b) of
    (False,False) -> (Pixel r (c+1), ToRight)
    (False,True)  -> (Pixel (r-1) c, ToUp)
    _             -> (Pixel r (c-1), ToLeft)
  where
    a = val8u im (Pixel (r-1) (c-1)) == v
    b = val8u im (Pixel (r-1) c) == v


-- | extracts a contour with given value from an image.
--   Don't use it if the region touches the limit of the image ROI.
rawContour :: ImageGray -- ^ source image
           -> Pixel     -- ^ starting point of the contour (a top-left corner)
           -> CUChar    -- ^ pixel value of the region (typically generated by some kind of floodFill or thresholding)
           -> [Pixel]   -- ^ contour of the region
rawContour im start v = clean $ iterate (nextPos im v) (start, ToRight)
    where clean ((a,_):rest) = a : clean' a rest
          clean' p ((v,_):rest) | p == v    = []
                                | otherwise = v: clean' p rest

-- | extracts a list of contours in the image
contours :: Int       -- ^ maximum number of contours
         -> Int       -- ^ minimum area (in pixels) of the admissible contours
         -> CUChar    -- ^ binarization threshold
         -> Bool      -- ^ binarization mode (True/False ->detect white/black regions)
         -> ImageGray -- ^ image source
         -> [([Pixel],Int,ROI)]  -- ^ list of contours, with area and ROI
contours n d th mode im = unsafePerformIO $ do
    aux <- binarize8u th mode im >>= copy8u
    auxCont n d aux

auxCont n d aux = do
    let (v,p) = maxIndx8u aux
    if n==0 || (v<255)
        then return []
        else do
            (r@(ROI r1 r2 c1 c2),a,_) <- floodFill8u aux p 128
            let ROI lr1 lr2 lc1 lc2 = theROI aux
            if a < d || r1 == lr1 || c1 == lc1 || r2 == lr2 || c2 == lc2
                    then auxCont n d aux
                    else do
                    let c = rawContour aux p 128
                    rest <- auxCont (n-1) d aux
                    return ((c,a,r):rest)
