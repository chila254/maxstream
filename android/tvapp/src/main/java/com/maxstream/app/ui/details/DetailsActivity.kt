package com.maxstream.app.ui.details

import android.os.Bundle
import androidx.fragment.app.FragmentActivity
import com.maxstream.app.data.model.MediaItem

class DetailsActivity : FragmentActivity() {
    companion object {
        const val EXTRA_ITEM = "extra_item"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) {
            val item = MediaItem.fromBundle(intent.getBundleExtra(EXTRA_ITEM)!!)
            supportFragmentManager.beginTransaction()
                .replace(android.R.id.content, DetailsFragment.newInstance(item))
                .commit()
        }
    }
}
