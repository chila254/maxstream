package com.maxstream.app.ui.shell

import android.os.Bundle
import androidx.fragment.app.Fragment
import androidx.fragment.app.FragmentActivity
import com.maxstream.app.R
import com.maxstream.app.ui.genre.GenreFragment
import com.maxstream.app.ui.home.HomeFragment
import com.maxstream.app.ui.more.MoreFragment
import com.maxstream.app.ui.search.SearchFragment
import com.maxstream.app.ui.series.SeriesFragment
import com.maxstream.app.ui.watchlist.WatchlistFragment

/**
 * Native port of the Dart [TvMaxStreamMain] shell: a left [SidebarView] plus a
 * content frame that swaps between the six sections. Content fragments are kept
 * alive (show/hide) so scroll/focus state is preserved like the Dart provider.
 */
class MainActivity : FragmentActivity() {

    private lateinit var sidebar: SidebarView
    private val fragments = mutableMapOf<Int, Fragment>()
    private var activeIndex = -1

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        sidebar = findViewById(R.id.sidebar)
        sidebar.onItemSelected = { index -> showSection(index) }
        if (savedInstanceState == null) {
            showSection(0)
        } else {
            activeIndex = savedInstanceState.getInt("active", 0)
            sidebar.setActive(activeIndex)
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putInt("active", activeIndex)
    }

    private fun createFragment(index: Int): Fragment = when (index) {
        0 -> HomeFragment()
        1 -> SearchFragment()
        2 -> GenreFragment()
        3 -> SeriesFragment()
        4 -> WatchlistFragment()
        else -> MoreFragment()
    }

    private fun showSection(index: Int) {
        sidebar.setActive(index)
        val fragment = fragments[index] ?: createFragment(index).also { fragments[index] = it }

        supportFragmentManager.beginTransaction().apply {
            fragments.forEach { (i, f) ->
                if (f.isAdded) {
                    if (i == index) show(f) else hide(f)
                }
            }
            if (!fragment.isAdded) add(R.id.content_frame, fragment, "section_$index")
            commitNow()
        }
        activeIndex = index
        // Move focus into the content area after a tab switch, mirroring the
        // Dart "_focusContent" behaviour.
        fragment.view?.requestFocus()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        if (activeIndex != 0) {
            showSection(0)
        } else {
            super.onBackPressed()
        }
    }
}
