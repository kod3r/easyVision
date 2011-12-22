{-# LANGUAGE ForeignFunctionInterface #-}
{-# LANGUAGE TemplateHaskell, RecordWildCards #-}
-----------------------------------------------------------------------------
{- |
Module      :  ImagProc.C.NP
Copyright   :  (c) Pedro E. Lopez de Teruel and Alberto Ruiz 2011
License     :  GPL

Maintainer  :  Alberto Ruiz (aruiz at um dot es)
Stability   :  provisional

Interface to the New Paradigm.

-}
-----------------------------------------------------------------------------

module ImagProc.C.NP (   
    npbRaw, npbParse, toPixels, npb,
    wnpcontours
)
where

import ImagProc.Ipp.Core
import ImagProc
import Foreign
import EasyVision.GUI.Parameters(autoParam,intParam)
import Contours.Base(douglasPeuckerClosed,douglasPeucker)
import ImagProc.Util((.@.))
import Control.Monad(when)

--------------------------------------------------------------------------------

foreign import ccall unsafe "getContoursAlberto"
    c_npb :: Ptr () -> Ptr () -> CInt -> CInt            -- ptr1 ptr2 step rows 
          -> CInt -> CInt -> CInt -> CInt                -- c1 c2 r1 r2
          -> Ptr (Ptr CInt) -> Ptr (Ptr CInt)            -- ps cs
          -> Ptr CInt -> Ptr CInt                        -- np nc
          -> IO ()

foreign import ccall unsafe "getContours"
   c_npb2 :: Ptr () -> Ptr () -> CInt -> CInt            -- ptr1 ptr2 step rows 
          -> CInt -> CInt -> CInt -> CInt                -- c1 c2 r1 r2
          -> Ptr (Ptr CInt) -> Ptr (Ptr CInt)            -- ps cs
          -> Ptr CInt -> Ptr CInt                        -- np nc
          -> IO ()

--------------------------------------------------------------------------------

npbRaw :: Int -> ImageGray -> ImageGray -> ([CInt], [CInt])
npbRaw mode x1 x2 = unsafePerformIO $ do
  let G im1 = x1
      G im2 = x2
      v z = fi . z . vroi $ im2
      cfun = [c_npb, c_npb2]

  when (mode==0) $ mapM_ ((flip (set 0)) x2) (invalidROIs x2) 
  
  ppp <- new nullPtr
  ppc <- new nullPtr
  pn <- new 0
  cn <- new 0

  (cfun!!mode) (ptr im1) (ptr im2)
               (fi.step $ im2) (fi.height.isize $ im2)
               (v c1) (v c2) (v r1) (v r2)
               ppp ppc pn cn
      
  pp <- peek ppp
  pc <- peek ppc
  p <- peek pn >>= flip peekArray pp . ti
  c <- peek cn >>= flip peekArray pc . ti
  mapM_ free [pn,cn,pp,pc]
  mapM_ free [ppp,ppc]
  mapM_ (touchForeignPtr.fptr) [im1,im2]
  return (p,c)

--------------------------------------------------------------------------------

npbParse :: CInt -> ([CInt], [CInt]) -> ([[Pixel]], [[Pixel]])
npbParse lmin (pts,szs) = go szs pts [] []
  where
    go  [] _ cls ops = (cls,ops)
    go [_] ps cls ops = (toPixels ps:cls,ops)
    go (n:m:ns) ps cls ops
        | m > 0     = go (m:ns) bs ncls ops 
        | otherwise = go   ns   ds cls  nops
      where
        (as,bs) = splitAt ( 2*(ti n)) ps
        (cs,ds) = splitAt (-2*(ti m)) bs
        ncls = if n >= lmin then toPixels as : cls else cls
        nops = if n-m >= lmin then (toPixelsI (reverse cs) ++ toPixels as) :ops else ops

-------------------------------------------------------------------------------

toPixels :: [CInt] -> [Pixel]
toPixels (x:y:zs) = Pixel (1+ti y) (1+ti x) : toPixels zs
toPixels _ = []

toPixelsI :: [CInt] -> [Pixel]
toPixelsI (x:y:zs) = Pixel (1+ti x) (1+ti y) : toPixelsI zs
toPixelsI _ = []


npb :: Int -> Int -> ImageGray -> ImageGray -> ([[Pixel]], [[Pixel]])
npb mode lmin x1 x2 = npbParse (fi lmin) . npbRaw mode x1 $ x2

--------------------------------------------------------------------------------

autoParam "NPParam" ""
    [ ("rad","Int",intParam 10 0 30)
    , ("th","Int",intParam 30 0 100)
    , ("minlen", "Int", intParam 50 0 200)]

wnpcontours :: IO ImageGray ->  IO (IO (ImageGray, ([Polyline],[Polyline])))
wnpcontours = npcontours .@. winNPParam

---------------------------------------

-- | result = (closed, open)
npcontours :: NPParam -> ImageGray -> ([Polyline],[Polyline])
npcontours NPParam{..} x = (map proc1 cl, map proc2 op)
  where
    y =  filterBox8u rad rad x
    mn = filterMin8u 2 x
    mx = filterMax8u 2 x
    dif = sub8u 0 mx mn
    mask = compareC8u (fromIntegral th) IppCmpGreater dif
    z = copyMask8u  y mask
    (cl,op) = npb 1 minlen x z
    proc1 = Closed . pixelsToPoints (size x). douglasPeuckerClosed 1.5
    proc2 = Open . pixelsToPoints (size x). douglasPeucker 1.5

---------------------------------------
