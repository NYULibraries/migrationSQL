/* This script assigns fake-ass barcodes to instances that don't have them. 
What gets a fauxcode? Instances with no barcode, but same indiciator, in the same resource and in the same series get the same faucode
This is important for helping the migrator create distinct top containers. 
Don't forget to delete fauxcodes from ASpace when this is all done! */

/* This script relies on functions found here: https://github.com/yalemssa/ATKreporting */

/* First, count how many fauxcodes you're going to end up with. This should be a count of the distinct, unbarcoded containers in your repository */
use mssa;
SELECT count(distinct(
    CONCAT('Faux.',
            CONCAT(r.resourceIdentifier1,
                    LPAD(r.resourceIdentifier2, 4, '00')),
            IF(series.subdivisionIdentifier <> '',
                CONCAT('.series', series.subdivisionIdentifier),
                ''),
                '.',
            adi.container1Type,
            IFNULL(adi.container1NumericIndicator, ''),
            IFNULL(adi.container1AlphaNumIndicator, '')))) fauxcode
FROM
    ArchDescriptionInstances adi
        JOIN
    ResourcesComponents rc ON adi.resourceComponentId = rc.resourceComponentId
        INNER JOIN
    Resources r ON r.resourceId = GETRESOURCEFROMCOMPONENT(rc.resourceComponentId)
        LEFT OUTER JOIN
    ResourcesComponents series ON GETTOPCOMPONENT(rc.resourceComponentId) = series.resourceComponentID
WHERE
    adi.barcode = ''

/* Now, get a report of all of your components without barcodes and see what the fauxcodes will look like */

use mssa;
SELECT 
    CONCAT(r.resourceIdentifier1,
            LPAD(r.resourceIdentifier2, 4, '00')) CallNo,
    r.title,
    series.subdivisionIdentifier,
    adi.container1Type,
    adi.container1NumericIndicator,
    adi.container1AlphaNumIndicator,
    CONCAT('Faux.',
            CONCAT(r.resourceIdentifier1,
                    LPAD(r.resourceIdentifier2, 4, '00')),
            IF(series.subdivisionIdentifier <> '',
                CONCAT('.series', series.subdivisionIdentifier),
                ''),
            '.',
            adi.container1Type,
            IFNULL(adi.container1NumericIndicator, ''),
            IFNULL(adi.container1AlphaNumIndicator, '')) fauxcode /*updated per Mary's email*/
FROM
    ArchDescriptionInstances adi
        JOIN
    ResourcesComponents rc ON adi.resourceComponentId = rc.resourceComponentId
        INNER JOIN
    Resources r ON r.resourceId = GETRESOURCEFROMCOMPONENT(rc.resourceComponentId)
        LEFT OUTER JOIN
    ResourcesComponents series ON GETTOPCOMPONENT(rc.resourceComponentId) = series.resourceComponentID
WHERE
    adi.barcode = ''

/* move common slide indicators into proper fields*/
UPDATE mssa.archdescriptioninstances 
SET container2NumericIndicator = substring_index(container1AlphaNumIndicator, 'F', -1)
    , container1AlphaNumIndicator = substring_index(container1AlphaNumIndicator, 'F', 1)
    , container2Type = 'Folder'
WHERE container1AlphaNumIndicator LIKE '%CS%';

/* here's a select statement to test it out before running for real:
select container1AlphaNumIndicator
, substring_index(container1AlphaNumIndicator, 'F', 1) as box
, substring_index(container1AlphaNumIndicator, 'F', -1) as folder
from archdescriptioninstances
WHERE
    container1AlphaNumIndicator LIKE '%CS%'

/* Now run the fauxcodes! */
use mssa;
UPDATE ArchDescriptionInstances adi
        JOIN
    ResourcesComponents rc ON adi.resourceComponentId = rc.resourceComponentId
        INNER JOIN
    Resources r ON r.resourceId = GETRESOURCEFROMCOMPONENT(rc.resourceComponentId)
        LEFT OUTER JOIN
    ResourcesComponents series ON GETTOPCOMPONENT(rc.resourceComponentId) = series.resourceComponentID 
SET 
    barcode = CONCAT('Faux.',
            CONCAT(r.resourceIdentifier1,
                    LPAD(r.resourceIdentifier2, 4, '00')),
            IF(series.subdivisionIdentifier <> '',
                CONCAT('.series', series.subdivisionIdentifier),
                ''),
            '.',
            adi.container1Type,
            IFNULL(adi.container1NumericIndicator, ''),
            IFNULL(adi.container1AlphaNumIndicator, ''))
WHERE
    adi.barcode = '';
update archDescriptionInstances set barcode=replace(barcode, ' ', '');



/* Delete fauxcodes from aspace */
update mssaaspace.top_container set barcode = null where barcode like '%Faux%';
