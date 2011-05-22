{-# LANGUAGE RecordWildCards #-}

import EasyVision
import Control.Arrow((&&&))

----------------------------------------------------------------------

main = run $ camera ~> f
           >>= observe "Hessian" hess 
           >>= observe "Harris"  harr
           >>= timeMonitor

f = (id &&& gradients . gaussS 2 . float) . resize (mpSize 10) . grayscale

----------------------------------------------------------------------

hess (im, g@Grads {..}) = r
  where
    r = blockImage [[ im    , sh gx   , sh gxx    ]
                   ,[ sh gy , sh gxy  , sh lap ]
                   ,[ sh gyy, toGray gs, sh h      ]]
    h = hessian g
    hn = (-1) .* h
    lap = 0.5 .* (gxx |+| gyy)
    gs = gaussS 2 gm

----------------------------------------------------------------------

harr (im, g@Grads {..}) = r
  where
    r = blockImage [[ im    , sh gx   , sh gx2    ]
                   ,[ sh gy , sh gxgy  , sha t2 ]
                   ,[ sh gy2, toGray gm , sha h ]]
    gx2 = gaussS 2 $ gx |*| gx
    gy2 = gaussS 2 $ gy |*| gy
    gxgy = gaussS 2 $ gx |*| gy
    d = gx2 |*| gy2 |-| gxgy |*| gxgy
    t = (gx2 |+| gy2)
    t2 = t |*| t
    h = d |+| (-0.1) .* t2

----------------------------------------------------------------------

sh = scale32f8u (-1) 1

sha x = toGray ((recip mx) .* x)
  where (_,mx) = minmax x

