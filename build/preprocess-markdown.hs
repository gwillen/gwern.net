{-# LANGUAGE OverloadedStrings #-}
module Main where

import Control.Monad (unless)
import qualified Data.Text as T (unpack)
import qualified Data.Text.IO as TIO (getContents)

import Text.Pandoc (def, pandocExtensions, runPure, readerExtensions, readMarkdown, writeHtml5String)
import Text.Pandoc.Walk (walk)

import LinkMetadata (cleanAbstractsHTML)
import LinkAuto (linkAuto)
import Interwiki (convertInterwikiLinks)
import qualified GenerateSimilar as GS (singleShotRecommendations)
import Utils (safeHtmlWriterOptions)

main :: IO ()
main = do originalMarkdown <- TIO.getContents

          let clean = runPure $ do
                pandoc <- readMarkdown def{readerExtensions=pandocExtensions} originalMarkdown
                let pandoc' = walk convertInterwikiLinks pandoc
                let pandoc'' = linkAuto pandoc'
                writeHtml5String safeHtmlWriterOptions pandoc''
          let html = case clean of
                 Left e -> error $ show e ++ ": " ++ show originalMarkdown
                 Right output -> cleanAbstractsHTML $ T.unpack output
          putStrLn html

          matchList <- GS.singleShotRecommendations html
          unless (matchList == "") $ putStrLn $ "<div class=\"collapse annotation-see-also\">\n\n<p><strong>See Also</strong>:</p>\n\n" ++ T.unpack matchList ++ "\n</div>"
