
import Classifier
import Classifier.ToyProblems
import Util.Stat
import Classifier.Regression(msError)
import Util.ICA
import Util.Misc(debug)

import Numeric.LinearAlgebra
import EasyVision hiding (debug, whitener)
import Data.Colour.Names as Col
import Graphics.UI.GLUT hiding (Size,scale)
import Data.Maybe(maybe)
import System.Random(randomIO)
import Text.Printf(printf)
import Control.Monad((>=>))

---------------------------------------------------------------------------

main = do
    democlas moon
    checkpca
    scatters (map return "0123")
    allDigits
    testBrowser 20 ["0","1"]

---------------------------------------------------------------------------

colors = [red,blue,orange,green]++repeat Col.lightgray

runIt f = prepare >> f >> mainLoop

scw title p = scatterPlot title (Size 400 400) p (0,1) colors (return ())

scwc title p clasif = scatterPlot title (Size 400 400) p (0,1) colors (drawRegion clasif p colors)

scwm title p met = scwc title p (mode . met p)

scwme title evi p met = scwc title p (maybe "REJECT" id . reject evi . met p)

scw3 title p = scatterPlot3D title 400 p (0,1,2) colors (return ())

rawmnist = loadExamples "../../../data/mnist.txt"

---------------------------------------------------------------------------

democlas x = do
    seed <- randomIO
    let p = addNoise seed 0.1 $ x 500
    runIt $ scw "examples" p
         >> scwm "D euc" p (distance euclidean)
         >> scwm "D Mah" p (distance mahalanobis)
         >> scwm "Gaussian" p (bayes gaussian)
         >> scwme "Gaussian, 3db" 3 p (bayes gaussian)
         >> scwm "Naive Gaussian" p (distance naiveGaussian)

---------------------------------------------------------------------------
-- check PCA reconstruction quality measured in sigma units

checkpca = do
    x <- map (fst) `fmap` rawmnist
    let xm = fromRows x
        st = stat xm
        xx = zip x x
        x0 = meanVector st
        codec = pca (SigmaPercent 90) st
        f = decodeVector codec . encodeVector codec
        e0 = msError (const x0) xx
        e = msError f xx
        cov = covarianceMatrix st
    printf "sigma0 cov: %7.3f\n"  $ sqrt $ (sumElements $ takeDiag cov) / fromIntegral (cols xm)
    printf "sigma0:     %7.3f\n" e0
    printf "sigma rec:  %7.3f\n" e
    printf "%.2f %% sigma - " $ 100 - 100*e/e0
    printf "%.2f %% var\n" $ 100 - 100*(e/e0)^2

---------------------------------------------------------------------------

examplesBrowser :: String -> Size -> (t -> IO a) -> Sample t -> IO (EVWindow (Int, Sample t))
examplesBrowser name sz f exs =
    evWindow (0,exs) name sz (Just disp) (mouseGen acts kbdQuit)
  where
    n = length exs - 1
    disp st = do
        (k,exs) <- get st
        let (x,label) = exs!!k
        f x
        windowTitle $= name++" #"++show (k+1)++ ": "++label
    acts = [((MouseButton WheelUp,   Down, modif), \(k,exs) -> (min (k+1) n, exs))
           ,((MouseButton WheelDown, Down, modif), \(k,exs) -> (max (k-1) 0, exs))]

showImage name img = evWindow img name (size img) (Just (get>=>drawImage)) (const kbdQuit)

shDigRaw v = drawImage $ mat2img  (reshape 28 v)

mat2img = fromListsF . toLists . single

shDig = shDigRaw . autoscale

autoscale v = (v - scalar b) / scalar (a-b)
  where a = maxElement v
        b = minElement v

testBrowser n c = do
    mnist <- rawmnist
    prepare
    let zeros = selectClasses c mnist
    examplesBrowser "MNIST" (Size 300 300) shDig zeros
    let x = fromRows $ map fst zeros
        st = stat x
        med = meanVector st
        pc = toRows $ eigenvectors $ st
        aux = map (\a -> (a,""))
    let codec = pca (NewDimension n) st
        red = encodeMatrix codec x
        wd = whitenedData . stat $ red
        w = whitener . stat $ red
        ica = fst . debug "err: " snd . icaTrans 50 (ica2 0.01) $ wd
        icaorig = toRows $ decodeMatrix codec (ica <> inv w) - asRow med
        icab = toRows $ ica <> (takeRows n $ eigenvectors st)
    examplesBrowser "IC" (Size 300 300) shDig (aux icaorig)
    let p = preprocess (mef (NewDimension n) zeros) zeros
    scw "PCA" p
    scw3 "PCA" $ boxAttr p `preprocess` p
    let pw = aux $ toRows $ wd
    scw3 "Whitened" $ boxAttr pw `preprocess` pw
    let pica = aux $ toRows $ wd <> trans ica
    scw "ICA" pica
    scw3 "ICA" pica
    showImage "PCA vs ICA" $ mat2img $ fromBlocks $ map (\x->map (reshape 28 . autoscale) (take n x)) [pc,icab]
    let expca k  = expand (fst $ zeros!!k) med (take n pc)
    showImage "Expansion PCA " $ mat2img $ autoscale $ fromBlocks $ map (\t->map (reshape 28 ) (take (n+3) t)) (map expca [0..9])
    let exica k  = expand (fst $ zeros!!k) med icab
    showImage "Expansion ICA " $ mat2img $ autoscale $ fromBlocks $ map (\t->map (reshape 28 ) (take (n+3) t)) (map exica [0..9])
    mainLoop
    --return $ fromRows icab <> trans (fromRows icab)

expand x m bs = x : r : map (scale 1) cs'  where
    ys = map (<.>(x - m)) bs
    cs = zipWith scale ys bs
    r = sum cs'
    n = fromIntegral $ length bs
    m' = scale (recip n) m
    cs' = map (+m')  cs

expand' x m bs = x : r : m : cs where
    ys = map (<.>(x - m)) bs
    cs = zipWith scale ys bs
    r = sum (m : cs)



---------------------------------------------------------

scatters s = do
    prepare
    raw <- rawmnist
    let sel = filter ((`elem` s) . snd) raw
    scw3 "PCA All" $ (boxAttr `ofP` mef (NewDimension 3)) raw `preprocess` raw
    scw3 ("PCA " ++ concat s) $ (boxAttr `ofP` mef (NewDimension 3)) sel `preprocess` sel

    let redu = mef (NewDimension 40) raw `preprocess` raw
        sel = filter ((`elem` s) . snd) redu
        sep = (boxAttr `ofP` mdf) sel `preprocess` sel
    scw3 "MDF "sep
    mainLoop

allDigits = do
    prepare
    raw <- rawmnist
    let dig d = do
           let they = filter ((`elem` [d]) . snd) raw
           scw3 (show d) $  (boxAttr `ofP` mef (NewDimension 3)) they `preprocess` they

    mapM_ dig (map return "0123456789")
    mainLoop