-- example of virtual camera

import EasyVision

-----------------------------------------------------------

interpolate = virtualCamera (return . inter)
    where inter (a:b:rest) = a: (0.5.*a |+| 0.5.*b) :inter (b:rest)

drift alpha = virtualCamera (return . drifter)
    where drifter (a:b:rest) = a : drifter ((alpha .* a |+| (1-alpha).* b):rest)

asFloat grab = return $ grab >>= yuvToGray >>= scale8u32f 0 1

------------------------------------------------------------

main = do

    sz <- findSize

    alpha <- getOption "--alpha" 0.9

    prepare

    (cam,ctrl) <- getCam 0 sz
                  >>= monitorizeIn "original" (Size 150 200) id
                  >>= asFloat
                  >>= drift alpha >>= interpolate
                  >>= withPause

    w <- evWindow () "interpolate" sz Nothing  (const (kbdcam ctrl))

    launch $ inWin w $ cam >>= drawImage
