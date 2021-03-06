#! /usr/bin/env runhaskell

import System.Environment(getEnv)

main = do
    ipp_inc <- getEnv "IPP_INC"
    ipp_sha <- getEnv "IPP_SHARED"
    ipp_lib <- getEnv "IPP_LIBS"
    ipp_lnk <- getEnv "IPP_LINK"
    putStrLn ipp_sha
    writeFile "imagproc.buildinfo" $ unlines
        [ "include-dirs: "   ++ipp_inc
        , "extra-lib-dirs: " ++ f ipp_sha
        , "extra-libraries: "++ipp_lib
        , "ld-options: "     ++ipp_lnk
        ]

f = map g

g ':' = ' '
g x = x

