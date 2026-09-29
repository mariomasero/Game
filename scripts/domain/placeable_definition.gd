class_name PlaceableDefinition
extends Resource

## Un mueble, mesa o maquina que se puede poner en la parcela del laboratorio
## (docs/decisions/014-parcela-y-camara.md). Es la definicion, que no cambia
## durante la partida; donde esta cada uno lo guarda PlotLayout.

## Identidad estable. Es lo que se guarda en la partida: renombrar el archivo o
## reordenar el catalogo no rompe nada, cambiar esto si.
@export var id: StringName

## Nombre para el jugador.
@export var nombre: String

## Casillas que ocupa sin girar: ancho (X) y fondo (Z). Tiene que coincidir con
## lo que mide el modelo; village.gd avisa en el editor si no.
@export var huella := Vector2i.ONE

## La escena VillageProp que se pone en el mundo.
@export var escena: PackedScene
