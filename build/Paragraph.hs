{-# LANGUAGE OverloadedStrings #-}
module Paragraph where

import Data.List (isInfixOf, intercalate)
import qualified Data.Text as T (breakOnAll, pack, unpack, Text)
import Utils (replace, printGreen, cleanAbstractsHTML, trim, toMarkdown, printRed, safeHtmlWriterOptions, anyInfix)
import Data.FileStore.Utils (runShellCommand)
import Text.Show.Pretty (ppShow)
import Text.Pandoc (def, pandocExtensions, readerExtensions, readMarkdown, runPure, writeHtml5String)
import System.Exit (ExitCode(ExitFailure))
import qualified Data.ByteString.Lazy.UTF8 as U (toString) -- TODO: why doesn't using U.toString fix the Unicode problems?

-- If a String (which is not HTML!) is a single long paragraph (has no double-linebreaks), call out to paragraphizer.py, which will use GPT-3 to try to break it up into multiple more-readable paragraphs.
-- This is quite tricky to use: it wants non-HTML plain text (any HTML will break GPT-3), but everything else wants HTML
processParagraphizer :: FilePath -> String -> IO String
processParagraphizer _ "" = return ""
processParagraphizer p a =
      if length a < 1024 || paragraphized p a then return a
      else do let a' = replace "<p>" "" $ replace "</p>" "" a
              let a'' = trim $ replace "\160" " " $ toMarkdown a'
              (status,_,mb) <- runShellCommand "./" Nothing "python" ["static/build/paragraphizer.py", a'']
              case status of
                ExitFailure err -> printGreen (intercalate " : " [a, a', ppShow status, ppShow err, ppShow mb]) >> printRed "Paragraphizer failed!" >> return a
                _ -> do let clean = runPure $ do
                              pandoc <- readMarkdown def{readerExtensions=pandocExtensions} (T.pack $ trim $ U.toString mb)
                              html <- writeHtml5String safeHtmlWriterOptions pandoc
                              return $ T.unpack html
                        case clean of
                              Left e -> error $ ppShow e ++ " : " ++ a
                              Right output -> return $ cleanAbstractsHTML output

-- Is an annotation (HTML or Markdown) already If the input has more than one <p>, or if there is one or more double-newlines, that means this input is already multiple-paragraphs
-- and we will skip trying to break it up further.
paragraphized :: FilePath -> String -> Bool
paragraphized f a = f `elem` whitelist ||
                  paragraphsMarkdown a || blockElements a || length (paragraphsHtml a) > 1
 where
   -- double newlines are only in Markdown strings, and split paragraphs:
   paragraphsMarkdown :: String -> Bool
   paragraphsMarkdown b = "\n\n" `isInfixOf` b
   blockElements :: String -> Bool
   -- full-blown lists or blockquotes also imply it's fully-formatted
   blockElements b = anyInfix b ["<ul>", "<ol>", "<ul type=", "<ol type=", "<blockquote>", "<figure>", "<table>"]
   -- annotations are wrapped in a '<p>...</p>' pair, unless they start with another block element; if there are two or more '<p>', then, there are at least two paragraphs (because it must be '<p>...</p> ... <p>...</p>') and it counts as being paragraphized.
   paragraphsHtml :: String -> [(T.Text,T.Text)]
   paragraphsHtml b = T.breakOnAll "<p>" (T.pack b)
   whitelist :: [String]
   whitelist = ["/doc/economics/1998-delong.pdf", "/doc/cs/algorithm/1980-rytter.pdf"]
