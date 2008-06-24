{-# OPTIONS -fbang-patterns #-}

import EasyVision
--import Data.List(transpose,minimumBy,foldl1')
import Graphics.UI.GLUT hiding (RGB,Size,minmax,histogram,Point,set)
import Debug.Trace
import Foreign
import ImagProc.Ipp.Core
import Text.Printf(printf)
import System.CPUTime
import GHC.Float(float2Double)
-- import Control.Monad(when)
-- import Control.Parallel.Strategies
import ImagProc.C.Simple(csum32f)
import Numeric.LinearAlgebra hiding ((.*))
import ImagProc.ImageFold
import ImagProc.Descriptors
import Vision(unitary,rot3)

main = do
    sz <- findSize
    (cam,ctrl) <- getCam 0 sz >>= withPause
    prepare
    o <- createParameters [("sc",realParam 2 0 5),
                           ("rot",realParam 0 (-180) 180)]
    w <- evWindow () "image fold test" sz Nothing  (const (kbdcam ctrl))

    launchFreq 25 $ do
        sc <- getParam o "sc"
        rot <- getParam o "rot"
        orig <- cam
        inWin w $ do
            let img = warp 0 (size orig) (rot3 (rot*pi/180)) $ float . gray . channels $ orig
            drawImage img
            let ims = [k.*img|k<-[1..10]]
            let roi = ROI 201 300 201 300
                (gx,gy,_,_,_) = secondOrder $ (sc .*) $ gaussS 1 $ modifyROI (const roi) img
                ga = abs32f gx |+| abs32f gy
            --drawROI (theROI ga)
            drawImage gy
--             putStrLn "------- "
--             timing $ print $ sum $ map (fst.minmax) ims
--             timing $ print $ (fst.minmax) ga
--             timing $ printf "%.1f\n" $ sum $ map sum32f ims
--             timing $ printf "%.1f\n" $ sum $ map csum32f ims
--             timing $ printf "%.1f\n" $ sum $ map (foldImage hsum 0) ims
--             timing $ printf "pixNum = %.1d\n" $ sum $ map (foldImage hcount (0::Int)) ims
            let hd = histodir ga gx gy
--             timing $ print hd
            setColor 1 0 0
            drawVector (5+c1 (theROI ga)) (r2 (theROI ga)) (1000*hd)
            let sd = usurfDesc 3 (gx,gy) roi
            drawVector (200+c1 (theROI ga)) (r2 (theROI ga)) (100*sd)
            print $ map (*(180/pi)) $ angles hd


hsum !p !k !s = s + float2Double (uval p k)
{-# INLINE hsum #-}

hcount !p !k !s = s+1
{-# INLINE hcount #-}

sumv v = v <.> constant 1 (dim v)