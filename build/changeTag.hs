#!/usr/bin/env runghc

-- CLI tool to add/remove link-tags to specified URLs/paths. eg. to add one tag: 'changeTag.hs
-- "https://en.wikipedia.org/wiki/Experience_curve_effects" "economics/experience-curve"'
-- To remove the tag, negate with a hyphen '-' prefix: "-economics/experience-curve"

-- This supports multiple mixed arguments; if there are multiple links and/or multiple tags
-- specified (as identified by links starting with '/' or 'http', and tags not starting with those &
-- also the necessary tag existing on disk), then we change all tags on all links (order
-- irrelevant).
--
-- eg. '$ changeTag.hs "https://en.wikipedia.org/wiki/Experience_curve_effects"
-- "economics/experience-curve" "genetics/heritable"
-- "https://www.genome.gov/about-genomics/fact-sheets/DNA-Sequencing-Costs-Data"' would add both tags on both
-- links.
-- or piping in URLs:
--
--  $ echo 'https://en.wikipedia.org/wiki/Subvocalization' | changeTag.hs psychology/inner-monologue
-- # Executing: psychology/inner-monologue tag on link: https://en.wikipedia.org/wiki/Subvocalization
-- # https://en.wikipedia.org/wiki/Subvocalization : "https://en.wikipedia.org/wiki/Subvocalization" : ("https://en.wikipedia.org/wiki/Subvocalization",("Subvocalization","","","",[],""))
-- # https://en.wikipedia.org/wiki/Subvocalization : ( "Subvocalization" , "" , "" , "" , [] , "" )
-- # Executing: psychology/inner-monologue tag on link: https://en.wikipedia.org/wiki/Subvocalization
--
-- Tags can be tagged by tagging their directory-index file (`/doc/$TAG1/index`); to do a one-way tag (to make $TAG1 'see also' $TAG2),
-- one does `changeTag.hs $TAG1 /doc/$TAG2/index`. Since it's common to want tags to be reciprocal or bidirectional, this is a shortcut,
-- just `changeTag.hs $TAG1 $TAG2`.
module Main where

import Control.Monad (when)
import Data.List (isPrefixOf)
import Data.Maybe (isJust, fromJust)
import System.Environment (getArgs)
import System.Directory (doesDirectoryExist, doesFileExist)
import Text.Pandoc (Inline(Link), nullAttr)
import qualified Data.Text as T (pack)

import LinkMetadata (annotateLink, readLinkMetadata, readYaml, writeYaml)
import LinkMetadataTypes (MetadataList, MetadataItem)
import Tags (guessTagFromShort, listTagsAll)
import Utils (printGreen, replace)

main :: IO ()
main = do
          -- read the regular CLI arguments
          args <- fmap (map $ (\a -> if "doc/"`isPrefixOf`a then "/"++a else a) . replace ".page" "" . replace "/home/gwern/wiki/" "/" . replace "https://gwern.net/" "/") getArgs

          when (length args < 2) $ error "Error: Insufficient arguments (<2)."
          when ("gwt" `elem` args) $ error "Invalid tag/URL 'gwt' detected! Is this entire command malformed? Exiting immediately."

          let links = filter (\arg -> " "/= arg && ""/=arg && (head arg == '/' || "http" `isPrefixOf` arg)) args
          allTags <- listTagsAll
          let tags = (filter (\t -> t `elem` allTags || tail t `elem` allTags) $ map (\t -> if head t == '-' then "-" ++ guessTagFromShort allTags (filter (/=',') $ tail t)
                                                                                            else guessTagFromShort allTags $ filter (/=',') t) $ -- we store tags comma-separated so sometimes we might leave in a stray tag when copy-pasting
                filter (\t -> t `notElem` links || ("-"++t) `notElem` links) args) :: [String]

          when (null tags) $ error ("Error: Forgot tags? " ++ show args)
          mapM_ (\arg' -> do filep <- doesDirectoryExist ("doc/"++ if head arg' == '-' then tail arg' else arg')
                             if not filep then error ("Error: Specified tag not defined? '" ++ arg' ++ "'") else return arg') tags
          if length tags == 2 && null links then
            -- setting up a bidirectional tag, equivalent to: changeTag.hs /doc/$TAG1/index $TAG2 && changeTag.hs /doc/$TAG2/index $TAG1
            changeOneTag ("/doc/" ++ head tags ++ "/index") (tags !! 1) >>
            changeOneTag ("/doc/" ++ (tags !! 1) ++ "/index") (head tags)
           else do
            when (null links) $ error ("Error: Forgot links?" ++ show args)
            mapM_ (\link -> mapM_ (changeOneTag link) tags) links

changeOneTag :: String -> String -> IO ()
changeOneTag link tag = do
          let link' = replace "https://gwern.net/" "/" link
          -- allow shortcut additions like 'changeTag.hs doc/foo.pdf psychology'
          link'' <- if not (head link' /= '/' && take 4 link' /= "http") then return link' else
                     do existP <- doesFileExist link'
                        if existP then return $ "/" ++ link' else
                          error $ "File does not exist? : '" ++ link' ++ "'"
          when (head tag == '/' || take 4 tag == "http") $ error $ "Arguments not 'changeTag.hs *tag* link'? : '" ++ tag ++ "'"
          [custom,half,auto] <- mapM readYaml ["metadata/full.yaml", "metadata/half.yaml", "metadata/auto.yaml"]
          printGreen ("Executing: " ++ tag ++ " tag on link: " ++ link'')
          changeAndWriteTags tag link'' custom half auto

-- If an annotation is in full.yaml, we only want to write that. If it's in half.yaml,
-- likewise. If it's in auto.yaml, now that we've added a tag to it, it is no longer disposable and
-- must be preserved by moving it from auto.yaml to half.yaml. If it's not in any metadata file
-- (such as a Wikipedia link, which is normally suppressed), then we add it to half.yaml.
changeAndWriteTags :: String -> String -> MetadataList -> MetadataList -> MetadataList -> IO ()
changeAndWriteTags t i c p a = do let cP = hasItem i c
                                      pP = hasItem i p
                                      aP = hasItem i a
                                  if cP then writeYaml "metadata/full.yaml" (changeTag i c t) else
                                    if pP then writeYaml "metadata/half.yaml" (changeTag i p t) else
                                      if aP then let (autoNew,halfNew) = mvItem a p i in writeYaml "metadata/auto.yaml" autoNew >> writeYaml "metadata/half.yaml" (changeTag i halfNew t)
                                      else addNewLink t i

-- what if a link is completely new and is not in either full.yaml (handwritten) or auto.yaml
-- (often auto-annotated)? If we write it directly into half.yaml, then for many links like
-- Arxiv/BioRxiv, we'd skip creating an automatic annotation!
--
-- So instead we hook back into the main link annotation workflow, create a new annotation for that
-- (which will be in auto.yaml), and then run changeTag.hs *again*, so this time it has an annotation
-- to work with (and will do auto.yaml → half.yaml).
addNewLink :: String -> String -> IO ()
addNewLink tag p = do md <- readLinkMetadata
                      _ <- annotateLink md (Link nullAttr [] (T.pack p, T.pack ""))
                      changeOneTag p tag -- if returnValue then changeOneTag p tag else error ("annotateLink returned False! " ++ show tag ++ " : " ++ show p)

changeTag, addTag, removeTag :: String -> MetadataList -> String -> MetadataList
changeTag "" a b  = error $ "changeTag called with empty arguments: " ++ "\"\""  ++ ":" ++ show a  ++ ":" ++ show b  ++ "; this should never happen."
changeTag  a [] b = error $ "changeTag called with empty arguments: " ++ show a  ++ ":" ++ "[]"    ++ ":" ++ show b  ++ "; this should never happen."
changeTag  a b "" = error $ "changeTag called with empty arguments: " ++ show a  ++ ":" ++ show b  ++ ":" ++ "\"\""  ++ "; this should never happen."
changeTag i ml tag = if head tag /= '-' then addTag i ml tag else removeTag i ml (tail tag)
addTag i ml tag = map (\(path,item@(a,b,c,d,e,f)) -> if i /= path || (tag `elem` e) then (path,item) else
                                                      (path,(a,b,c,d,e++[tag],f)) ) ml
removeTag i ml tag = map (\(path,item@(a,b,c,d,e,f)) -> if i /= path || (tag `notElem` e) then (path,item) else
                                                      (path,(a,b,c,d,filter (/= tag) e,f)) ) ml

mvItem :: MetadataList -> MetadataList -> String -> (MetadataList,MetadataList)
mvItem original new i = (removeItem original i,
                          new ++ [(i, fromJust $ getItem original i)])

getItem :: MetadataList -> String -> Maybe MetadataItem
getItem ml i = lookup i ml

removeItem :: MetadataList -> String -> MetadataList
removeItem ml i = filter (\(p,_) -> p /= i) ml

hasItem :: String -> MetadataList -> Bool
hasItem i ml = isJust $ getItem ml i
