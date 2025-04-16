package funkin.states;

import funkin.data.CharacterData;
import openfl.media.Sound;
import funkin.scripts.Globals;
import funkin.data.Cache;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.text.FlxText;
import flixel.FlxCamera;
import flixel.util.FlxStringUtil;
import funkin.data.Highscore;

class GameOverSubstate extends MusicBeatSubstate
{
	public static var instance:GameOverSubstate;

	public static var characterName:String = null;
	public static var deathSoundName:String = 'fnf_loss_sfx';
	public static var loopSoundName:String = 'gameOver';
	public static var endSoundName:String = 'gameOverEnd';
	
	public static var genericName:String;
	public static var genericSound:String;
	public static var genericMusic:String;

	// TODO: or to undo...
	public static var voicelineNumber:Null<Int> = null; // set this value to play an specific voiceline (otherwise it will be randomly chosen using the voicelineAmount value)
	public static var voicelineAmount:Int = 0; // how many voicelines exist.
	public static var voicelineName:Null<String> = null; // if set to null then it will just use the character name

	/** Whether to wait for the confirm sound to end before switching to the menus. */
	public static var waitForEndSound:Bool = false; // false by default because the base fnf sound is long af

	//////
	public var boyfriend:Character;
	public var genericBitch:FlxSprite; // TODO: Get rid of this!!! think of some way to do game over screens that don't use the player character instance
	public var deathSound:FlxSound;

	private var _musicAsset:Sound = null; // lag, maybe the music isn't getting properly cached but im just gonna do this for now

	public var camFollow:FlxPoint;
	public var camFollowPos:FlxObject;

	public var cameraSpeed:Float = 1.0;
	public var defaultCamZoom:Float = 1.0;
	public var updateCamera:Bool = false;

	var songText:FlxText;
	var timeText:FlxText;
	var scoreText:FlxText;

	var camScore:FlxCamera;

	/** Whether key presses to continue or go to the menus are processed */
	private var canEnd:Bool = false;
	/** True after ACCEPT or BACK were pressed */
	private var isEnding:Bool = false;

	public static function resetVariables() {
		characterName = null;
		deathSoundName = 'fnf_loss_sfx';
		loopSoundName = 'gameOver';
		endSoundName = 'gameOverEnd';

		genericName = 'characters/gameover/generic${FlxG.random.int(1,5)}'; 
		genericSound = "gameoverGeneric";
		genericMusic = "";

		voicelineNumber = null;
		voicelineAmount = 0;
		voicelineName = null;

		waitForEndSound = false;
	}

	override function create()
	{
		instance = this;

		FlxG.timeScale = 1.0;
		
		FlxG.camera.bgColor = FlxColor.BLACK;
		FlxG.camera.follow(camFollowPos, LOCKON, 1);

		Conductor.songPosition = 0;
		Conductor.changeBPM(100);

		if (genericBitch != null){
			startGeneric();
		}else{
			deathSound = FlxG.sound.play(Paths.sound(deathSoundName));
			boyfriend.playAnim('firstDeath');
		}

		canEnd = true;

		PlayState.instance.setOnScripts('inGameOver', true);
		PlayState.instance.callOnScripts('onGameOverStart', []);

		super.create();
	}

	override function destroy(){
		if (camFollow != null)
			camFollow.put();

		instance = null;

		super.destroy();
	}

	inline function startGeneric() {
		var tweens:Array<FlxTween> = [];
		inline function doTween(goals:Dynamic, dur:Float, ?props:flixel.tweens.FlxTween.TweenOptions)
			tweens.push(FlxTween.tween(genericBitch, goals, dur, props));
		
		final frameDur:Float = 1/24;
		genericBitch.alpha = 0.0;
		genericBitch.scale.set(2.25, 2.25);

		doTween({"scale.x": 1.220, "scale.y": 1.220, alpha: 1}, 1, {ease: FlxEase.circIn});				
		doTween({"scale.x": 1.196, "scale.y": 1.196}, frameDur, {
			onComplete: (_)->{ 
				if (!isEnding) 
					FlxG.sound.play(Paths.sound(genericSound), false);
			}}
		);
		doTween({"scale.x": 1.1, "scale.y": 1.1}, frameDur*35);
		doTween({"scale.x": 1.0, "scale.y": 1.0}, frameDur * 60, {
			onStart: (_) ->{
				if (!isEnding)
					FlxG.sound.playMusic(Paths.music(genericMusic), 0.6, true);
				
				if (FlxG.sound.music != null)
					FlxG.sound.music.fadeIn(0.4, 0.6, 1.0);
			}
		});
		doTween({"scale.x": 1.01, "scale.y": 1.01}, frameDur * 24, {type: PINGPONG});
		
		for (i in 0...tweens.length-1)
			tweens[i].then(tweens[i+1]);
		tweens = null;
	}

	function doGenericGameOver()
	{
		Cache.loadWithList([
			{path: genericName, type: 'IMAGE'},
			{path: genericSound, type: 'SOUND'},
			{path: genericMusic, type: 'MUSIC'},
			{path: endSoundName, type: 'MUSIC'}
		]);

		genericBitch = new FlxSprite(0, 0, Paths.image(genericName));
		genericBitch.scrollFactor.set();
		genericBitch.screenCenter();
		add(genericBitch);
	}

	public function new(?char:Character)
	{
		super();

		var game = PlayState.instance;

		inline function warn(txt:String)
			if (game.showDebugTraces) trace(txt);

		if (char == null){
			warn('Character is null.'); // Can't position death character without it
			return doGenericGameOver();
		}

		var deathName:String = (characterName != null) ? characterName : (char.characterId + "-dead");
		var charInfo = CharacterData.getCharacterFile(deathName);

		if (charInfo == null){
			warn('Could not get Character data for "$deathName".');
			deathName = char.characterId;
			charInfo = CharacterData.getCharacterFile(deathName);
		}

		if (charInfo == null){
			warn('Could not get Character data for "$deathName".');
			charInfo = CharacterData.getCharacterFile("bf");
		}

		////		
		Cache.loadWithList([
			{path: charInfo.image, type: 'IMAGE'},
			{path: deathSoundName, type: 'SOUND'},
			{path: loopSoundName, type: 'MUSIC'},
			{path: endSoundName, type: 'MUSIC'}
		]);

		_musicAsset = Paths.music(loopSoundName);

		boyfriend = new Character(
			char.x - char.positionArray[0], 
			char.y - char.positionArray[1], 
			deathName, 
			char.isPlayer
		);
		boyfriend.startScripts();
		boyfriend.setupCharacter();
		boyfriend.x += boyfriend.positionArray[0];
		boyfriend.y += boyfriend.positionArray[1];
		add(boyfriend);

		camFollow = boyfriend.getGraphicMidpoint();
		camFollowPos = new FlxObject(game.camFollowPos.x, game.camFollowPos.y);
		add(camFollowPos);

		if (game.stage != null)
			defaultCamZoom = game.stage.stageData.defaultZoom;
		else
			defaultCamZoom = FlxG.camera.zoom;

		//SCORE BS!!

		var prevTime = Conductor.songPosition - ClientPrefs.noteOffset;
		var ratingPercent = game.totalPlayed == 0 ? 0 : game.stats.ratingPercent;
		var shownScore:String = ClientPrefs.showWifeScore ? Std.string(Math.floor(game.stats.totalNotesHit * 100)) : Std.string(Math.floor(game.stats.score));

		camScore = new FlxCamera();
		camScore.bgColor.alpha = 0;
		FlxG.cameras.add(camScore, false);

		songText = new FlxText(0, 0, 0, '${game.displayedSong} - ${game.displayedDifficulty.toUpperCase()}', 20);
		if (ClientPrefs.getGameplaySetting('instakill', false) == true) songText.text += ' [SUDDEN DEATH]';
		songText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		songText.borderSize = 1.5;
		songText.antialiasing = true;
		songText.setPosition(FlxG.width - songText.width - 40, FlxG.height * 0.84);
		songText.alpha = 0;
		add(songText);

		timeText = new FlxText(0, 0, 0, '${FlxStringUtil.formatTime((Math.max(prevTime, 0) / 1000))} / ${FlxStringUtil.formatTime(PlayState.instance.songLength / 1000)}', 20);
		timeText.setFormat(Paths.font("vcr.ttf"), 20, (prevTime >= 1) ? FlxColor.WHITE : 0xFF727272, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		timeText.borderSize = 1.5;
		timeText.antialiasing = true;
		timeText.setPosition(FlxG.width - timeText.width - 40, FlxG.height * 0.84 + 22);
		timeText.alpha = 0;
		add(timeText);

		scoreText = new FlxText(0, 0, 0, 'Score: ${shownScore} / ${Highscore.floorDecimal(ratingPercent * 100, 2)}%', 28);
		scoreText.setFormat(Paths.font("vcr.ttf"), 28, (game.stats.score >= 1) ? FlxColor.WHITE : 0xFF727272, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreText.borderSize = 1.5;
		scoreText.antialiasing = true;
		scoreText.setPosition(FlxG.width - scoreText.width - 40, FlxG.height * 0.84 + (22 * 2));
		scoreText.alpha = 0;
		add(scoreText);

		songText.cameras = [camScore];
		timeText.cameras = [camScore];
		scoreText.cameras = [camScore];
	}

	var isFollowingAlready:Bool = false;

	function endGameOver(?retry:Bool){
		if (isEnding && retry != false) 
			return;

		var ret = PlayState.instance.callOnScripts('onGameOverConfirm', [retry]);
		if (ret == Globals.Function_Stop)
			return;

		if (retry == true)
			onConfirm();
		else if (retry == false)
			onCancel();
	}

	function onConfirm()
	{
		isEnding = true;

		if (FlxG.sound.music != null) 
			FlxG.sound.music.stop();

		if (genericBitch != null){
			FlxTween.cancelTweensOf(genericBitch);
			FlxTween.tween(genericBitch, {alpha: 0, "scale.x": 0, "scale.y": 0}, 100/120, {ease: FlxEase.quadIn, onComplete: (_)->{remove(genericBitch).destroy();}});
		}
		
		if (boyfriend != null)
			boyfriend.playAnim('deathConfirm', true);
		
		var endSound = FlxG.sound.play(Paths.music(endSoundName));

		if (waitForEndSound){
			var endTime = Math.max(endSound.length/1000, 2.7); // wait for both the sound and the fade out to end.

			new FlxTimer().start(0.7,		(tmr) -> FlxG.camera.fade(FlxColor.BLACK, 2, false));
			new FlxTimer().start(endTime,	(tmr) -> MusicBeatState.resetState(true));
			return;
		}

		new FlxTimer().start(0.7, function onComplete(tmr){
			FlxG.camera.fade(FlxColor.BLACK, 2, false, function onFadeComplete(){
				if (endSound.playing)
					endSound.fadeOut(Math.min(0.6, (endSound.length - endSound.time) / 1000), 0.0, (_) -> MusicBeatState.resetState(true));
				else
					MusicBeatState.resetState(true);
			});
		});
		
		doTextCancel(2);
	}

	function onCancel(){
		isEnding = true;

		/*if (FlxG.sound.music != null) 
			FlxG.sound.music.stop();*/

		if (genericBitch != null)
			FlxTween.cancelTweensOf(genericBitch);

		FlxG.sound.play(Paths.sound('cancelMenu'), 0.8);

		if (FlxG.sound.music != null) 
			FlxTween.tween(FlxG.sound.music, {pitch: 0, volume: 0}, 1.5, {
				onComplete: function(_){FlxG.sound.music.stop();}
			});

		doTextCancel(2);
		FlxG.camera.fade(FlxColor.BLACK, 2, false, function onFadeComplete(){
			PlayState.gotoMenus();
		});
	}

	function doTextStuff()
	{
		songText.y -= 20;
		timeText.y -= 20;
		scoreText.y -= 20;
		FlxTween.tween(songText, {alpha: 1, y: songText.y + 20}, 0.4, {ease: FlxEase.quadOut});
		FlxTween.tween(timeText, {alpha: 1, y: timeText.y + 20}, 0.4, {ease: FlxEase.quadOut, startDelay: 0.3});
		FlxTween.tween(scoreText, {alpha: 1, y: scoreText.y + 20}, 0.4, {ease: FlxEase.quadOut, startDelay: 0.6});
	}

	function doTextCancel(length:Float = 2)
	{
		FlxTween.cancelTweensOf(songText);
		FlxTween.cancelTweensOf(timeText);
		FlxTween.cancelTweensOf(scoreText);
		FlxTween.tween(songText, {alpha: 0}, length, {ease: FlxEase.linear});
		FlxTween.tween(timeText, {alpha: 0}, length, {ease: FlxEase.linear});
		FlxTween.tween(scoreText, {alpha: 0}, length, {ease: FlxEase.linear});
	}
	
	override function update(elapsed:Float)
	{
		PlayState.instance.callOnScripts('onUpdate', [elapsed]);

		if (!isEnding && boyfriend != null && boyfriend.animation.name == 'firstDeath')
		{
			if(boyfriend.animation.curAnim.curFrame >= 12 && !isFollowingAlready)
			{
				updateCamera = true;
				isFollowingAlready = true;
			}

			if (boyfriend.animation.curAnim.finished)
			{
				boyfriend.playAnim('deathLoop');
				FlxG.sound.playMusic(_musicAsset, 1);
				doTextStuff();
			}
		}

		if (updateCamera && genericBitch == null) {
			var lerpVal:Float = Math.exp(-elapsed * 0.6 * cameraSpeed);
			camFollowPos.setPosition(
				FlxMath.lerp(camFollow.x, camFollowPos.x, lerpVal), 
				FlxMath.lerp(camFollow.y,  camFollowPos.y, lerpVal)
			);
			
			var lerpVal:Float = Math.exp(-elapsed * 2.2);
			FlxG.camera.zoom = FlxMath.lerp(defaultCamZoom, FlxG.camera.zoom, lerpVal);
		}

		if (FlxG.sound.music != null && FlxG.sound.music.playing)
			Conductor.songPosition = FlxG.sound.music.time;

		if (canEnd){
			if (controls.ACCEPT)
				endGameOver(true);

			if (controls.BACK)
				endGameOver(false);
		}
		
		PlayState.instance.callOnScripts('onUpdatePost', [elapsed]);
		super.update(elapsed);
	}

	override function beatHit()
	{
		super.beatHit();
		
		boyfriend.playAnim('deathLoop');
	}
}