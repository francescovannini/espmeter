DROP TABLE IF EXISTS `log`;
CREATE TABLE `log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ts` datetime NOT NULL DEFAULT current_timestamp(),
  `timedrift` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;


DROP TABLE IF EXISTS `counter`;
CREATE TABLE `counter` (
  `idlog` int(11) NOT NULL,
  `slot` smallint(6) NOT NULL,
  `pulses` tinyint(3) unsigned NOT NULL,
  PRIMARY KEY (`idlog`,`slot`),
  CONSTRAINT `fk_counter_1` FOREIGN KEY (`idlog`) REFERENCES `log` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;


DROP TABLE IF EXISTS `vcc`;
CREATE TABLE `vcc` (
  `idlog` int(11) NOT NULL,
  `ts` datetime NOT NULL,
  `vcc` float DEFAULT NULL,
  PRIMARY KEY (`ts`,`idlog`),
  KEY `fk_vcc_1_idx` (`idlog`),
  CONSTRAINT `fk_vcc_1` FOREIGN KEY (`idlog`) REFERENCES `log` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;


DROP VIEW IF EXISTS `pulses_over_time`;
CREATE VIEW `pulses_over_time` AS
    SELECT 
        `l`.`ts` + INTERVAL (`c`.`slot` * 5) MINUTE AS `ts`,
        `c`.`pulses` AS `pulses`
    FROM
        (`log` `l`
        JOIN `counter` `c` ON (`l`.`id` = `c`.`idlog`));


DROP VIEW IF EXISTS `pulses_over_day`;
CREATE VIEW `pulses_over_day` AS
    SELECT 
        CAST(`pulses_over_time`.`ts` AS DATE) AS `ts`,
        SUM(`pulses_over_time`.`pulses`) AS `pulses`
    FROM
        `pulses_over_time`
    GROUP BY CAST(`pulses_over_time`.`ts` AS DATE);


DROP VIEW IF EXISTS `pulses_over_hour`;
CREATE VIEW `pulses_over_hour` AS
    SELECT 
        CAST(`pulses_over_time`.`ts` AS DATE) + INTERVAL HOUR(`pulses_over_time`.`ts`) HOUR AS `ts`,
        SUM(`pulses_over_time`.`pulses`) AS `pulses`
    FROM
        `pulses_over_time`
    GROUP BY CAST(`pulses_over_time`.`ts` AS DATE) , HOUR(`pulses_over_time`.`ts`);
