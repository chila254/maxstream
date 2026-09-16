package com.maxstream.app.util

import com.maxstream.app.data.local.ProfileScope
import com.maxstream.app.data.local.ProfileData
import android.content.Context

/** TMDB genre IDs for kid-friendly content. */
private const val GENRE_ANIMATION = 16
private const val GENRE_FAMILY = 10751

/** Returns true if the item has kid-friendly genres. */
fun isKidFriendly(genreIds: List<Int>): Boolean =
    genreIds.contains(GENRE_ANIMATION) || genreIds.contains(GENRE_FAMILY)

/** Whether the active profile is a kids profile. */
fun isKidsProfile(context: Context): Boolean =
    ProfileScope.activeProfile(context)?.isKids == true
