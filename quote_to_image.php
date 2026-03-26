<?php

// This script turns quotes from books into images for use on a Kobo Clara HD clock.
// Ported from Kindle version by Jaap Meijers, 2018

error_reporting(E_ALL);
ini_set("display_errors", 1);

$imagenumber = 0;
$previoustime = 0;

putenv('GDFONTPATH=' . realpath('.'));
$font_path = "LinLibertine_RZ";
$font_path_bold = "LinLibertine_RB";
$creditFont = "LinLibertine_RZI";

$row = 1;
if (($handle = fopen("litclock_annotated.csv", "r")) !== FALSE) {
    while (($data = fgetcsv($handle, 1000, "|")) !== FALSE) {
        $num = count($data);
        $row++;
        $time = $data[0];
        $timestring = trim($data[1]);
        $quote = $data[2];
        $quote = trim(preg_replace('/\s+/', ' ', $quote));
        $title = trim($data[3]);
        $author = trim($data[4]);

        TurnQuoteIntoImage($time, $quote, $timestring, $title, $author);
    }
    fclose($handle);
}



function TurnQuoteIntoImage($time, $quote, $timestring, $title, $author) {

    global $font_path;
    global $font_path_bold;
    global $creditFont;

    // Kobo Clara HD: 1072 x 1448 at 300ppi (portrait)
    $width = 1072;
    $height = 1448;

    $margin = 46;

    $timestringStarts = count(explode(' ', stristr($quote, $timestring, true)))-1;
    $timestring_wordcount = count(explode(' ', $timestring))-1;

    $quote_array = explode(' ', $quote);

    $time = substr($time, 0, 2).substr($time, 3, 2);

    // Start font size higher to account for larger resolution
    $font_size = 32;

    list($png_image) = fitText($quote_array, $width, $height, $font_size, $timestringStarts, $timestring_wordcount, $margin);

    global $imagenumber;
    global $previoustime;
    if ($time == $previoustime) {
        $imagenumber++;
    } else {
        $imagenumber = 0;
    }
    $previoustime = $time;

    print "Image for " . $time .'_'. $imagenumber . "\n";

    imagepng($png_image, 'images/quote_'.$time.'_'.$imagenumber.'.png');


    ///// METADATA /////

    $grey = imagecolorallocate($png_image, 125, 125, 125);
    $black = imagecolorallocate($png_image, 0, 0, 0);

    $dash = "—";

    $credits = $title . ", " . $author;
    $creditFont_size = 32;

    list($metawidth, $metaheight, $metaleft, $metatop) = measureSizeOfTextbox($creditFont_size, $creditFont, $dash . $credits);

    if ( $metawidth > 900 ) {

        $newCredits = array();
        $creditsArray = explode(" ", $credits);
        $i = 1;

        while ( True ) {
            $tmp0 = implode(" ", array_slice($creditsArray, 0, count($creditsArray)-$i));
            $tmp1 = implode(" ", array_slice($creditsArray, 0-$i));

            if ( strlen($tmp1)+5 > strlen($tmp0) ) {
                break;
            } else {
                $newCredits[0] = $tmp0;
                $newCredits[1] = $tmp1;
            }
            $i++;
        }

        list($textWidth1, $textheight1) = measureSizeOfTextbox($creditFont_size, $creditFont, $dash . $newCredits[0]);
        list($textWidth2, $textheight2) = measureSizeOfTextbox($creditFont_size, $creditFont, $newCredits[1]);

        $metadataX1 = $width-($textWidth1+$margin);
        $metadataX2 = $width-($textWidth2+$margin);
        $metadataY = $height-$margin;

        imagettftext($png_image, $creditFont_size, 0, $metadataX1, $metadataY-($textheight1*1.1), $black, $creditFont, $dash . $newCredits[0]);
        imagettftext($png_image, $creditFont_size, 0, $metadataX2, $metadataY, $black, $creditFont, $newCredits[1]);

    } else {

        $metadataX = ($width-$metaleft)-$margin;
        $metadataY = $height-$margin;

        imagettftext($png_image, $creditFont_size, 0, $metadataX, $metadataY, $black, $creditFont, $dash . $credits);
    }

    imagepng($png_image, 'images/metadata/quote_'.$time.'_'.$imagenumber.'_credits.png');

    imagedestroy($png_image);

    // convert to greyscale
    $im = new Imagick();
    $im->readImage('images/quote_'.$time.'_'.$imagenumber.'.png');
    $im->setImageType(Imagick::IMGTYPE_GRAYSCALE);
    unlink('images/quote_'.$time.'_'.$imagenumber.'.png');
    $im->writeImage('images/quote_'.$time.'_'.$imagenumber.'.png');

    $im = new Imagick();
    $im->readImage('images/metadata/quote_'.$time.'_'.$imagenumber.'_credits.png');
    $im->setImageType(Imagick::IMGTYPE_GRAYSCALE);
    unlink('images/metadata/quote_'.$time.'_'.$imagenumber.'_credits.png');
    $im->writeImage('images/metadata/quote_'.$time.'_'.$imagenumber.'_credits.png');
}


function fitText($quote_array, $width, $height, $font_size, $timestringStarts, $timestring_wordcount, $margin) {

    global $font_path_bold;
    global $font_path;

    $png_image = imagecreate($width, $height)
        or die("Cannot Initialize new GD image stream");
    $background_color = imagecolorallocate($png_image, 255, 255, 255);

    $grey = imagecolorallocate($png_image, 125, 125, 125);
    $black = imagecolorallocate($png_image, 0, 0, 0);

    $timeLocation = 0;
    $lineWidth = 0;

    $position = array($margin,$margin+$font_size);

    foreach($quote_array as $key => $word) {

        if ( in_array($key, range($timestringStarts, $timestringStarts+$timestring_wordcount)) ) {
            $font = $font_path_bold;
            $textcolor = $black;
        } else {
            $font = $font_path;
            $textcolor = $grey;
        }

        list($textwidth, $textheight) = measureSizeOfTextbox($font_size, $font, $word . " ");

        if ( $textwidth > ($width - $margin) ) {
            return False;
        }

        if ( ($position[0] + $textwidth) >= ($width - $margin) ) {
            $position[0] = $margin;
            $position[1] = $position[1] + round($font_size*1.618);
            imagettftext($png_image, $font_size, 0, $position[0], $position[1], $textcolor, $font, $word);
        } else {
            imagettftext($png_image, $font_size, 0, $position[0], $position[1], $textcolor, $font, $word);
        }

        $position[0] += $textwidth;
    }

    // Leave room for credits below
    $paragraphHeight = $position[1];
    if ( $paragraphHeight < $height-180 ) {
        $result = fitText($quote_array, $width, $height, $font_size+1, $timestringStarts, $timestring_wordcount, $margin);
        if ( $result !== False ) {
            list($png_image, $paragraphHeight, $font_size, $timeLocation) = $result;
        };
    } else {
        return False;
    }

    return array($png_image, $paragraphHeight, $font_size, $timeLocation);
}

function measureSizeOfTextbox($font_size, $font_path, $text) {

    $box = imagettfbbox($font_size, 0, $font_path, $text);

    $min_x = min( array($box[0], $box[2], $box[4], $box[6]) );
    $max_x = max( array($box[0], $box[2], $box[4], $box[6]) );
    $min_y = min( array($box[1], $box[3], $box[5], $box[7]) );
    $max_y = max( array($box[1], $box[3], $box[5], $box[7]) );

    $width  = ( $max_x - $min_x );
    $height = ( $max_y - $min_y );
    $left   = abs( $min_x ) + $width;
    $top    = abs( $min_y ) + $height;

    return array($width, $height, $left, $top);
}

?>
